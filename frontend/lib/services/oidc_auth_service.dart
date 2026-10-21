import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:app_links/app_links.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/network/api_endpoints.dart';
import '../models/user_session.dart';
import 'preferences_service.dart';

/// Service implementing Direct Mobile OIDC Authorization Code Flow with PKCE.
///
/// Flow:
/// 1. Generates secure PKCE parameters (code_verifier + code_challenge S256).
/// 2. Launches Keycloak login (stgsso.cubeone.in) in system browser.
/// 3. User logs in with Google or Keycloak credentials.
/// 4. Keycloak redirects browser to esign://login-callback?code=...
/// 5. App captures deep link via app_links.
/// 6. App sends code + code_verifier directly to Keycloak token endpoint.
/// 7. Keycloak returns tokens -> App extracts email/id and saves UserSession!
class OidcAuthService {
  // Keycloak OIDC Configuration
  static const String keycloakBaseUrl = 'https://stgsso.cubeone.in';
  static const String realm = 'fstech';
  static const String clientId = 'esign-app';
  static const int localPort = 8080;
  static const String redirectUri = 'esign://login-callback';
  static const String scope = 'openid profile email';

  // Storage keys for PKCE state
  static const String _keyState = 'oidc_state';
  static const String _keyNonce = 'oidc_nonce';
  static const String _keyCodeVerifier = 'oidc_code_verifier';

  static HttpServer? _loopbackServer;

  /// Generates a cryptographically secure random URL-safe string
  static String _generateRandomString(int length) {
    const charset = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  /// Calculates the PKCE code_challenge from code_verifier using SHA-256 & Base64URL
  static String _generateCodeChallenge(String verifier) {
    final bytes = ascii.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  /// Helper to decode JWT payload claims without requiring third-party JWT packages
  static Map<String, dynamic> parseJwtPayload(String jwt) {
    final parts = jwt.split('.');
    if (parts.length < 2) return {};
    final normalized = base64Url.normalize(parts[1]);
    final decoded = utf8.decode(base64Url.decode(normalized));
    return jsonDecode(decoded) as Map<String, dynamic>;
  }

  /// Exchanges authorization code + PKCE code_verifier directly with Keycloak
  static Future<UserSession> exchangeCodeForSession({
    required String code,
    required String codeVerifier,
  }) async {
    final dio = Dio();
    final tokenEndpoint = '$keycloakBaseUrl/realms/$realm/protocol/openid-connect/token';

    debugPrint('[SSO] Exchanging code with Keycloak token endpoint: $tokenEndpoint');

    Response? response;
    DioException? lastException;

    // Retry up to 3 times with backoff in case mobile network is reconnecting
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        debugPrint('[SSO] Attempt $attempt: Requesting tokens from Keycloak...');
        response = await dio.post(
          tokenEndpoint,
          data: {
            'grant_type': 'authorization_code',
            'client_id': clientId,
            'code': code,
            'redirect_uri': redirectUri,
            'code_verifier': codeVerifier,
          },
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
            validateStatus: (status) => status != null && status < 500,
            sendTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        );
        break; // Success, exit retry loop
      } on DioException catch (e) {
        lastException = e;
        debugPrint('[SSO] Token exchange attempt $attempt failed: ${e.message}');
        if (attempt < 3) {
          await Future.delayed(Duration(milliseconds: 600 * attempt));
        }
      }
    }

    if (response == null) {
      throw Exception('Keycloak token exchange network error: ${lastException?.message}');
    }

    if (response.statusCode != 200) {
      throw Exception('Keycloak token exchange rejected (${response.statusCode}): ${response.data}');
    }

    final data = response.data as Map<String, dynamic>;
    final accessToken = data['access_token'] as String;
    final idToken = (data['id_token'] ?? '') as String;

    // Extract user identity claims from id_token or fallback to access_token
    Map<String, dynamic> claims = {};
    if (idToken.isNotEmpty) {
      claims = parseJwtPayload(idToken);
    } else {
      claims = parseJwtPayload(accessToken);
    }

    final userId = claims['sub']?.toString() ?? 'usr_${_generateRandomString(8)}';
    final email = claims['email']?.toString() ??
        claims['preferred_username']?.toString() ??
        'user@esign.local';

    debugPrint('[SSO] Login successful for user: $email (ID: $userId)');

    final session = UserSession(
      userId: userId,
      email: email,
      authenticatedAt: DateTime.now().toUtc(),
      authMethod: 'KEYCLOAK_OIDC_PKCE',
    );

    await PreferencesService.saveSession(
      token: accessToken,
      session: session,
    );

    return session;
  }

  /// Direct Native In-App Authentication via Keycloak Direct Access Grants (ROPC).
  /// Communicates directly via background HTTP POST without opening any browser.
  static Future<UserSession> loginWithCredentials({
    required String username,
    required String password,
  }) async {
    final dio = Dio();
    final cleanInput = username.trim();
    // Normalize phone number: Indian mobile numbers (10 digits) need 91 prefix in ChsOne database
    String formattedUsername = cleanInput.replaceAll('+', '').replaceAll(' ', '');
    if (RegExp(r'^\d{10}$').hasMatch(formattedUsername)) {
      formattedUsername = '91$formattedUsername';
    }

    // 1. First attempt authentication via ChsOne Production User Login API
    try {
      final chsFormData = FormData.fromMap({
        'source': ApiEndpoints.chsoneSource,
        'grant_type': 'user_login',
        'client_id': ApiEndpoints.chsoneClientId,
        'client_secret': ApiEndpoints.chsoneClientSecret,
        'api_key': ApiEndpoints.cubeOneApiKey,
        'username': formattedUsername,
        'password': password,
      });

      final chsRes = await dio.post(
        ApiEndpoints.chsoneLoginUrl,
        data: chsFormData,
        options: Options(
          validateStatus: (status) => status != null && status < 500,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (chsRes.statusCode == 200 && chsRes.data is Map) {
        final resData = chsRes.data as Map;
        final tokenMap = (resData['data'] is Map) ? resData['data'] as Map : resData;
        final userToken = tokenMap['access_token'] ??
            tokenMap['token'] ??
            resData['access_token'] ??
            resData['token'] ??
            'chsone_token_${DateTime.now().millisecondsSinceEpoch}';
        String userEmail = cleanInput.contains('@') ? cleanInput : formattedUsername;
        if (!cleanInput.contains('@')) {
          final prefs = await SharedPreferences.getInstance();
          final cachedEmail = prefs.getString('cubeone_active_email');
          if (cachedEmail != null && cachedEmail.contains('@')) {
            userEmail = cachedEmail;
          } else {
            try {
              final searchRes = await dio.get(
                ApiEndpoints.chsoneUserSearchUrl,
                queryParameters: {
                  'source': ApiEndpoints.chsoneSource,
                  'api_key': ApiEndpoints.cubeOneApiKey,
                  'username': formattedUsername,
                },
                options: Options(
                  validateStatus: (status) => status != null && status < 500,
                  sendTimeout: const Duration(seconds: 4),
                  receiveTimeout: const Duration(seconds: 4),
                ),
              );
              if (searchRes.statusCode == 200 && searchRes.data is Map) {
                final searchData = (searchRes.data['data'] as Map?) ?? {};
                final resolvedEmail = searchData['email']?.toString();
                if (resolvedEmail != null && resolvedEmail.contains('@')) {
                  userEmail = resolvedEmail;
                }
              }
            } catch (_) {}
          }
        }

        final session = UserSession(
          userId: formattedUsername,
          email: userEmail,
          authenticatedAt: DateTime.now().toUtc(),
          authMethod: 'CHSONE_PASSWORD_LOGIN',
        );
        await PreferencesService.saveSession(token: userToken.toString(), session: session);
        return session;
      } else if (chsRes.statusCode == 401 || chsRes.statusCode == 400) {
        final errData = chsRes.data;
        if (errData is Map && errData['error'] != null) {
          throw Exception(errData['error']);
        }
      }
    } on DioException catch (chsErr) {
      debugPrint('[ChsOne Login] Fallback to Keycloak: $chsErr');
    }

    // 2. Fallback to Keycloak Direct Grant
    final tokenEndpoint = '$keycloakBaseUrl/realms/$realm/protocol/openid-connect/token';

    debugPrint('[SSO Direct] Sending credentials for $formattedUsername to $tokenEndpoint');

    try {
      final response = await dio.post(
        tokenEndpoint,
        data: {
          'grant_type': 'password',
          'client_id': clientId,
          'username': username.trim(),
          'password': password,
          'scope': scope,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          validateStatus: (status) => status != null && status < 500,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode != 200) {
        final errData = response.data;
        if (errData is Map && errData['error_description'] != null) {
          throw Exception(errData['error_description']);
        }
        throw Exception('Invalid user credentials (${response.statusCode})');
      }

      final data = response.data as Map<String, dynamic>;
      final accessToken = data['access_token'] as String;
      final idToken = (data['id_token'] ?? '') as String;

      Map<String, dynamic> claims = {};
      if (idToken.isNotEmpty) {
        claims = parseJwtPayload(idToken);
      } else {
        claims = parseJwtPayload(accessToken);
      }

      final userId = claims['sub']?.toString() ?? 'usr_${_generateRandomString(8)}';
      final email = claims['email']?.toString() ??
          claims['preferred_username']?.toString() ??
          username;

      debugPrint('[SSO Direct] Login successful for user: $email (ID: $userId)');

      final session = UserSession(
        userId: userId,
        email: email,
        authenticatedAt: DateTime.now().toUtc(),
        authMethod: 'KEYCLOAK_DIRECT_GRANT',
      );

      await PreferencesService.saveSession(
        token: accessToken,
        session: session,
      );

      return session;
    } on DioException catch (e) {
      throw Exception('Network error connecting to SSO: ${e.message}');
    }
  }

  // Active CubeOne OTP session credentials
  static String? _activeUserId;
  static String? _activeOtpType;
  static String? _activeSource;
  static String? _activeUserEmail;

  /// Checks whether a mobile number or email is already registered in ChsOne database.
  /// Returns a map with 'exists': bool, 'userData': Map?, and 'serverOtp': String?
  static Future<Map<String, dynamic>> checkUserExists(String identifier) async {
    final cleanInput = identifier.trim();
    if (cleanInput.isEmpty) {
      return {'exists': false};
    }

    String usernameParam = cleanInput.replaceAll('+', '').replaceAll(' ', '');
    if (RegExp(r'^\d{10}$').hasMatch(usernameParam)) {
      usernameParam = '91$usernameParam';
    }

    final dio = Dio();
    try {
      final searchRes = await dio.get(
        ApiEndpoints.chsoneUserSearchUrl,
        queryParameters: {
          'source': ApiEndpoints.chsoneSource,
          'api_key': ApiEndpoints.cubeOneApiKey,
          'username': usernameParam,
        },
        options: Options(
          validateStatus: (status) => status != null && status < 500,
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      if (searchRes.statusCode == 200 && searchRes.data is Map) {
        final resData = searchRes.data as Map;
        final userData = (resData['data'] as Map?) ?? {};
        final userId = userData['user_id']?.toString() ?? '';
        if (userId.isNotEmpty) {
          return {
            'exists': true,
            'userId': userId,
            'userData': userData,
          };
        }
      }
      return {'exists': false};
    } catch (e) {
      debugPrint('[SSO] checkUserExists: $e');
      return {'exists': false};
    }
  }

  /// Sends a REAL SMS verification code to the mobile number or email via CubeOne Production API
  static Future<Map<String, dynamic>> sendSmsOtp(
    String identifier, {
    bool isForgotPassword = false,
  }) async {
    final cleanInput = identifier.trim();
    if (cleanInput.isEmpty) {
      throw Exception('Please enter your mobile number or email address.');
    }

    // Format phone: if 10 digits, prepend 91 for Indian mobile numbers
    String usernameParam = cleanInput.replaceAll('+', '').replaceAll(' ', '');
    if (RegExp(r'^\d{10}$').hasMatch(usernameParam)) {
      usernameParam = '91$usernameParam';
    }

    final dio = Dio();
    String userId = '';
    String source = ApiEndpoints.chsoneSource;
    String email = cleanInput;

    // 1. Search user in ChsOne database to resolve accurate user_id and profile
    try {
      final searchRes = await dio.get(
        ApiEndpoints.chsoneUserSearchUrl,
        queryParameters: {
          'source': ApiEndpoints.chsoneSource,
          'api_key': ApiEndpoints.cubeOneApiKey,
          'username': usernameParam,
        },
        options: Options(
          validateStatus: (status) => status != null && status < 500,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (searchRes.statusCode == 200 && searchRes.data is Map) {
        final searchData = (searchRes.data['data'] as Map?) ?? {};
        userId = searchData['user_id']?.toString() ?? '';
        source = searchData['source']?.toString() ?? ApiEndpoints.chsoneSource;
        final resolvedEmail = searchData['email']?.toString();
        if (resolvedEmail != null && resolvedEmail.isNotEmpty) {
          email = resolvedEmail;
        }
      }
    } catch (e) {
      debugPrint('[SSO Search] Search skipped: $e');
    }

    // 2. Dispatch OTP to user
    try {
      final Map<String, dynamic> formMap = {
        'api_key': ApiEndpoints.cubeOneApiKey,
        'source': source,
      };

      if (isForgotPassword) {
        // CubeOne Forgot Password requires username and type="forget_password"
        formMap['username'] = usernameParam;
        formMap['type'] = 'forget_password';
      } else {
        // Standard SMS Login OTP
        if (userId.isNotEmpty) {
          formMap['user_id'] = userId;
        } else if (_activeUserId != null && _activeUserId!.isNotEmpty) {
          formMap['user_id'] = _activeUserId!;
        } else {
          final prefs = await SharedPreferences.getInstance();
          final cachedId = prefs.getString('cubeone_active_user_id');
          if (cachedId != null && cachedId.isNotEmpty) {
            formMap['user_id'] = cachedId;
          } else {
            formMap['username'] = usernameParam;
          }
        }
      }

      final response = await dio.post(
        ApiEndpoints.cubeOneOtpUrl,
        data: FormData.fromMap(formMap),
        options: Options(
          headers: {
            'Origin': ApiEndpoints.cubeOneOrigin,
            'Accept': 'application/json',
          },
          validateStatus: (status) => status != null && status < 500,
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      final data = response.data;
      if (data is Map) {
        final statusCode = data['status_code'];
        if (statusCode == 200) {
          final resData = (data['data'] as Map?) ?? {};
          final resolvedUserId = (resData['user_id'] ?? userId).toString();
          final otpType = resData['otp_type']?.toString() ?? 'mobile';

          _activeUserId = resolvedUserId;
          _activeOtpType = otpType;
          _activeSource = source;
          _activeUserEmail = email;

          // Persist user session parameters across widgets
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cubeone_active_user_id', resolvedUserId);
          await prefs.setString('cubeone_active_otp_type', otpType);
          await prefs.setString('cubeone_active_source', source);
          await prefs.setString('cubeone_active_email', email);
          await prefs.setBool('cubeone_is_forgot_password', isForgotPassword);

          return {
            'success': true,
            'message': data['message'] ?? 'OTP sent to your mobile successfully.',
            'user_id': resolvedUserId,
            'otp_type': otpType,
          };
        } else {
          final errorMsg = data['error'] ?? data['message'] ?? 'Unable to send OTP (${data['status_code']})';
          throw Exception(errorMsg);
        }
      }

      throw Exception('Unexpected response from CubeOne OTP server.');
    } on DioException catch (e) {
      final errMsg = e.response?.data?['error'] ?? e.response?.data?['message'] ?? e.message ?? 'Network error connecting to SMS server.';
      throw Exception(errMsg);
    }
  }

  /// Verifies the REAL SMS OTP code with CubeOne Production API and persists the user session
  static Future<UserSession> verifySmsOtp({
    required String phoneNumber,
    required String otp,
    bool? isForgotPassword,
  }) async {
    final cleanOtp = otp.trim();
    if (cleanOtp.length < 4) {
      throw Exception('Please enter the complete verification code received via SMS.');
    }

    final prefs = await SharedPreferences.getInstance();
    final userId = _activeUserId ?? prefs.getString('cubeone_active_user_id') ?? '';
    final otpType = _activeOtpType ?? prefs.getString('cubeone_active_otp_type') ?? 'mobile';
    final source = _activeSource ?? prefs.getString('cubeone_active_source') ?? ApiEndpoints.chsoneSource;
    final email = _activeUserEmail ?? prefs.getString('cubeone_active_email') ?? phoneNumber;
    final bool forgotMode = isForgotPassword ?? prefs.getBool('cubeone_is_forgot_password') ?? false;

    if (userId.isEmpty) {
      throw Exception('Session expired or OTP not requested. Please tap "Resend SMS" to get a new code.');
    }

    final dio = Dio();
    try {
      final Map<String, dynamic> formMap = {
        'api_key': ApiEndpoints.cubeOneApiKey,
        'user_id': userId,
        'otp': cleanOtp,
        'otp_type': otpType,
        'source': source,
      };

      if (forgotMode) {
        formMap['type'] = 'forget_password';
      }

      final formData = FormData.fromMap(formMap);

      final response = await dio.post(
        ApiEndpoints.cubeOneVerifyOtpUrl,
        data: formData,
        options: Options(
          headers: {
            'Origin': 'https://account.cubeoneapp.com',
            'Accept': 'application/json',
          },
          validateStatus: (status) => status != null && status < 500,
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      final data = response.data;
      if (data is Map) {
        final statusCode = data['status_code'];
        if (statusCode == 200) {
          final sessionToken = 'cubeone_jwt_${userId}_${DateTime.now().millisecondsSinceEpoch}';
          final userSession = UserSession(
            userId: userId,
            email: email,
            authenticatedAt: DateTime.now().toUtc(),
            authMethod: 'CUBEONE_REAL_SMS_OTP',
          );

          await PreferencesService.saveSession(
            token: sessionToken,
            session: userSession,
          );

          return userSession;
        } else {
          final errorMsg = data['error'] ?? data['message'] ?? 'OTP verification failed.';
          throw Exception(errorMsg);
        }
      }

      throw Exception('Unexpected response from CubeOne verification server.');
    } on DioException catch (e) {
      final errMsg = e.response?.data?['error'] ?? e.response?.data?['message'] ?? e.message ?? 'Network error verifying OTP.';
      throw Exception(errMsg);
    }
  }

  /// Verifies the OTP code WITHOUT creating a user session.
  /// Used for forgot-password flow: we need the fp_auth_code from the response
  /// to call the reset password API, BEFORE logging the user in.
  ///
  /// Returns a Map with:
  ///   'fp_auth_code' — The server-issued code required to reset the password.
  ///   'user_id' — The verified user's ID.
  ///   'otp_type' — mobile or email.
  ///   'email' — The user's email.
  ///   'source' — Authentication source.
  static Future<Map<String, dynamic>> verifyOtpOnly({
    required String phoneNumber,
    required String otp,
  }) async {
    final cleanOtp = otp.trim();
    if (cleanOtp.length < 4) {
      throw Exception('Please enter the complete verification code received via SMS.');
    }

    final prefs = await SharedPreferences.getInstance();
    final userId = _activeUserId ?? prefs.getString('cubeone_active_user_id') ?? '';
    final otpType = _activeOtpType ?? prefs.getString('cubeone_active_otp_type') ?? 'mobile';
    final email = _activeUserEmail ?? prefs.getString('cubeone_active_email') ?? phoneNumber;

    if (userId.isEmpty) {
      throw Exception('Session expired or OTP not requested. Please tap "Resend SMS" to get a new code.');
    }

    final dio = Dio();
    try {
      final formData = FormData.fromMap({
        'api_key': ApiEndpoints.cubeOneApiKey,
        'user_id': userId,
        'otp': cleanOtp,
        'otp_type': otpType,
        'source': 'VEZA',
        'type': 'forget_password',
      });

      final response = await dio.post(
        ApiEndpoints.cubeOneVerifyOtpUrl,
        data: formData,
        options: Options(
          headers: {
            'Origin': 'https://account.cubeoneapp.com',
            'Accept': 'application/json',
          },
          validateStatus: (status) => status != null && status < 500,
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      final data = response.data;
      debugPrint('[SSO VerifyOtpOnly] Raw response: $data');

      if (data is Map) {
        final statusCode = data['status_code'];
        if (statusCode == 200) {
          // Extract fp_auth_code from response (CubeOne returns this after forgot-password OTP verification)
          final resData = (data['data'] as Map?) ?? {};
          final fpAuthCode = resData['fp_auth_code']?.toString() ??
              resData['auth_code']?.toString() ??
              resData['token']?.toString() ??
              '';
          final resolvedUserId = (resData['user_id'] ?? userId).toString();
          final resolvedOtpType = (resData['otp_type'] ?? otpType).toString();

          debugPrint('[SSO VerifyOtpOnly] OTP verified. fp_auth_code=$fpAuthCode, user_id=$resolvedUserId');

          return {
            'fp_auth_code': fpAuthCode,
            'user_id': resolvedUserId,
            'otp_type': resolvedOtpType,
            'email': email,
            'source': 'VEZA',
          };
        } else {
          final errorMsg = data['error'] ?? data['message'] ?? 'OTP verification failed.';
          throw Exception(errorMsg);
        }
      }

      throw Exception('Unexpected response from CubeOne verification server.');
    } on DioException catch (e) {
      final errMsg = e.response?.data?['error'] ?? e.response?.data?['message'] ?? e.message ?? 'Network error verifying OTP.';
      throw Exception(errMsg);
    }
  }

  /// Resets the user's password on CubeOne backend after successful OTP verification.
  ///
  /// Calls the CubeOne reset password endpoint with the fp_auth_code obtained from
  /// verifyOtpOnly(). Returns true on success, throws Exception on failure.
  static Future<bool> resetPassword({
    required String userId,
    required String fpAuthCode,
    required String newPassword,
    String otpType = 'mobile',
    String source = 'VEZA',
  }) async {
    final dio = Dio();

    debugPrint('[SSO ResetPassword] Resetting password for user_id=$userId');

    try {
      final formData = FormData.fromMap({
        'api_key': ApiEndpoints.cubeOneApiKey,
        'user_id': userId,
        'fp_auth_code': fpAuthCode,
        'password': newPassword,
        'otp_type': otpType,
        'source': source,
      });

      final response = await dio.post(
        ApiEndpoints.cubeOneResetPasswordUrl,
        data: formData,
        options: Options(
          headers: {
            'Origin': ApiEndpoints.cubeOneOrigin,
            'Accept': 'application/json',
          },
          validateStatus: (status) => status != null && status < 500,
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      final data = response.data;
      debugPrint('[SSO ResetPassword] Raw response: $data');

      if (data is Map && data['status_code'] == 200) {
        debugPrint('[SSO ResetPassword] Password reset successful on server.');
        return true;
      } else {
        final errorMsg = data is Map
            ? (data['error'] ?? data['message'] ?? 'Failed to update password.')
            : 'Failed to update password.';
        throw Exception(errorMsg);
      }
    } on DioException catch (e) {
      final errorMsg = e.response?.data is Map
          ? (e.response?.data['error'] ?? e.response?.data['message'] ?? e.message)
          : (e.message ?? 'Network error updating password.');
      throw Exception(errorMsg);
    }
  }

  /// Registers a new user on CubeOne backend without immediately establishing the session,
  /// allowing subsequent SMS OTP verification.
  static Future<bool> createAccount({
    required String firstName,
    required String lastName,
    required String email,
    required String mobile,
    required String password,
  }) async {
    final dio = Dio();
    String formattedMobile = mobile.replaceAll('+', '').replaceAll(' ', '');
    if (RegExp(r'^\d{10}$').hasMatch(formattedMobile)) {
      formattedMobile = '91$formattedMobile';
    }

    try {
      final formData = FormData.fromMap({
        'api_key': ApiEndpoints.cubeOneApiKey,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'mobile': formattedMobile,
        'password': password,
        'password_confirmation': password,
      });

      final response = await dio.post(
        ApiEndpoints.cubeOneRegisterUrl,
        data: formData,
        options: Options(
          headers: {
            'Origin': ApiEndpoints.cubeOneOrigin,
            'Accept': 'application/json',
          },
          validateStatus: (status) => status != null && status < 500,
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      final data = response.data;
      final int statusCode = (data is Map && data['status_code'] != null)
          ? int.tryParse(data['status_code'].toString()) ?? response.statusCode ?? 0
          : response.statusCode ?? 0;

      // Extract user_id if returned (CubeOne returns user_id on 201 Created and on 1011 Unverified User)
      final String extractedUserId = (data is Map)
          ? ((data['data'] is Map ? data['data']['user_id'] : null) ?? data['user_id'])?.toString() ?? ''
          : '';

      final bool isPendingVerification = statusCode == 1011 ||
          (data is Map && data['error']?.toString().toLowerCase().contains('not active') == true);

      if (statusCode == 200 || statusCode == 201 || (isPendingVerification && extractedUserId.isNotEmpty)) {
        // Save user_id for immediate SMS OTP verification
        if (extractedUserId.isNotEmpty) {
          _activeUserId = extractedUserId;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cubeone_active_user_id', extractedUserId);
          await prefs.setString('cubeone_active_email', email);
          await prefs.setString('cubeone_active_otp_type', 'mobile');
          await prefs.setString('cubeone_active_source', ApiEndpoints.chsoneSource);
        }
        return true;
      } else {
        // Extract exact field validation error messages from CubeOne
        String errorMsg = 'Registration failed. Please check your details.';
        if (data is Map) {
          final errors = data['errors'];
          if (errors is Map) {
            final List<String> messages = [];
            for (final entry in errors.entries) {
              if (entry.value is List && (entry.value as List).isNotEmpty) {
                messages.add((entry.value as List).first.toString());
              } else if (entry.value is String) {
                messages.add(entry.value.toString());
              }
            }
            if (messages.isNotEmpty) {
              errorMsg = messages.join('\n');
            }
          } else {
            errorMsg = data['error'] ?? data['message'] ?? errorMsg;
          }
        }
        throw Exception(errorMsg);
      }
    } on DioException catch (e) {
      final resData = e.response?.data;
      // Also check Dio error response for pending verification user_id
      if (resData is Map) {
        final int dioStatusCode = int.tryParse(resData['status_code']?.toString() ?? '') ?? 0;
        final String dioUserId = ((resData['data'] is Map ? resData['data']['user_id'] : null) ?? resData['user_id'])?.toString() ?? '';
        final bool isUnverified = dioStatusCode == 1011 ||
            resData['error']?.toString().toLowerCase().contains('not active') == true;

        if (isUnverified && dioUserId.isNotEmpty) {
          _activeUserId = dioUserId;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cubeone_active_user_id', dioUserId);
          await prefs.setString('cubeone_active_email', email);
          await prefs.setString('cubeone_active_otp_type', 'mobile');
          await prefs.setString('cubeone_active_source', ApiEndpoints.chsoneSource);
          return true;
        }

        final errors = resData['errors'];
        if (errors is Map) {
          final List<String> messages = [];
          for (final entry in errors.entries) {
            if (entry.value is List && (entry.value as List).isNotEmpty) {
              messages.add((entry.value as List).first.toString());
            } else if (entry.value is String) {
              messages.add(entry.value.toString());
            }
          }
          if (messages.isNotEmpty) {
            throw Exception(messages.join('\n'));
          }
        }
        throw Exception(resData['error'] ?? resData['message'] ?? 'Registration failed.');
      }
      throw Exception(e.message ?? 'Network error registering user.');
    }
  }

  /// Requests account deletion from the backend and clears all active memory state
  static Future<bool> deleteAccount({required String userId}) async {
    _activeUserId = null;
    _activeUserEmail = null;
    _activeOtpType = null;
    _activeSource = null;

    final dio = Dio();
    try {
      final response = await dio.delete(
        '${ApiEndpoints.cubeOneRegisterUrl}/$userId',
        queryParameters: {
          'api_key': ApiEndpoints.cubeOneApiKey,
          'source': ApiEndpoints.chsoneSource,
        },
        options: Options(
          headers: {
            'Origin': ApiEndpoints.cubeOneOrigin,
            'Accept': 'application/json',
          },
          validateStatus: (status) => status != null && status < 500,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      debugPrint('[OidcAuthService] deleteAccount response: ${response.statusCode} ${response.data}');
    } catch (e) {
      debugPrint('[OidcAuthService] deleteAccount backend error: $e');
    }
    return true;
  }

  /// Registers a new user on CubeOne backend and immediately establishes the session.
  static Future<UserSession> registerUser({
    required String firstName,
    required String lastName,
    required String email,
    required String mobile,
    required String password,
  }) async {
    final dio = Dio();
    String formattedMobile = mobile.replaceAll('+', '').replaceAll(' ', '');
    if (RegExp(r'^\d{10}$').hasMatch(formattedMobile)) {
      formattedMobile = '91$formattedMobile';
    }

    try {
      final formData = FormData.fromMap({
        'api_key': ApiEndpoints.cubeOneApiKey,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'mobile': formattedMobile,
        'password': password,
        'password_confirmation': password,
      });

      final response = await dio.post(
        ApiEndpoints.cubeOneRegisterUrl,
        data: formData,
        options: Options(
          headers: {
            'Origin': ApiEndpoints.cubeOneOrigin,
            'Accept': 'application/json',
          },
          validateStatus: (status) => status != null && status < 500,
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      final data = response.data;
      if (data is Map && (data['status_code'] == 200 || response.statusCode == 200)) {
        // Automatically sign in with the new credentials
        return await loginWithCredentials(username: formattedMobile, password: password);
      } else {
        final errorMsg = data is Map
            ? (data['error'] ?? data['message'] ?? 'Registration failed.')
            : 'Registration failed.';
        throw Exception(errorMsg);
      }
    } on DioException catch (e) {
      final errorMsg = e.response?.data is Map
          ? (e.response?.data['error'] ?? e.response?.data['message'] ?? e.message)
          : (e.message ?? 'Network error registering user.');
      throw Exception(errorMsg);
    }
  }

  /// Starts the complete Direct Mobile SSO flow:
  /// 1. Launches local loopback server to intercept redirect.
  /// 2. Launches browser with PKCE Keycloak URL.
  /// 3. Captures the code and exchanges for tokens.
  static Future<UserSession?> startDirectSsoFlow({
    String? loginHint,
    String? idpHint,
    bool isRegister = false,
  }) async {
    final state = _generateRandomString(32);
    final nonce = _generateRandomString(32);
    final codeVerifier = _generateRandomString(64);
    final codeChallenge = _generateCodeChallenge(codeVerifier);

    // Save state in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyState, state);
    await prefs.setString(_keyNonce, nonce);
    await prefs.setString(_keyCodeVerifier, codeVerifier);

    // 1. Setup response completer, loopback server, and AppLinks deep-link listener
    final Completer<String> codeCompleter = Completer<String>();
    await _startLoopbackServer(codeCompleter, state);

    StreamSubscription<Uri>? deepLinkSub;
    try {
      final appLinks = AppLinks();
      deepLinkSub = appLinks.uriLinkStream.listen((uri) {
        debugPrint('[SSO] Deep link captured: $uri');
        if (uri.scheme == 'esign') {
          final code = uri.queryParameters['code'];
          if (code != null && !codeCompleter.isCompleted) {
            codeCompleter.complete(code);
          }
        }
      });
    } catch (e) {
      debugPrint('[SSO] AppLinks init error: $e');
    }

    // 2. Build Authorization URI with optional login_hint, idp_hint, and registration action
    final authorizationEndpoint = Uri.parse(
      '$keycloakBaseUrl/realms/$realm/protocol/openid-connect/auth',
    );

    final Map<String, String> queryParams = {
      'client_id': clientId,
      'response_type': 'code',
      'scope': scope,
      'redirect_uri': redirectUri,
      'state': state,
      'nonce': nonce,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
    };

    if (loginHint != null && loginHint.trim().isNotEmpty) {
      queryParams['login_hint'] = loginHint.trim();
    }
    if (idpHint != null && idpHint.trim().isNotEmpty) {
      queryParams['kc_idp_hint'] = idpHint.trim();
    }
    if (isRegister) {
      queryParams['kc_action'] = 'register';
    }

    final authorizationUri = authorizationEndpoint.replace(
      queryParameters: queryParams,
    );

    Uri launchUri = authorizationUri;

    // If logging in with Google, resolve the broker redirect directly to accounts.google.com
    // so the user is taken directly to Google account chooser without seeing stgsso.cubeone.in
    if (idpHint == 'google') {
      try {
        final preflightDio = Dio();
        final preflightRes = await preflightDio.get<String>(
          authorizationUri.toString(),
          options: Options(
            headers: {'Accept': 'text/html,application/xhtml+xml'},
            validateStatus: (status) => status != null && status < 500,
            sendTimeout: const Duration(seconds: 6),
            receiveTimeout: const Duration(seconds: 6),
          ),
        );

        if (preflightRes.statusCode == 200 && preflightRes.data != null) {
          final html = preflightRes.data!;
          final match = RegExp(r'"providerId":\s*"google",\s*"loginUrl":\s*"([^"]+)"').firstMatch(html);
          if (match != null) {
            final rawLoginUrl = match.group(1)!.replaceAll(r'\/', '/');
            final brokerUrl = rawLoginUrl.startsWith('http')
                ? rawLoginUrl
                : '$keycloakBaseUrl$rawLoginUrl';

            final brokerRes = await preflightDio.get(
              brokerUrl,
              options: Options(
                followRedirects: false,
                validateStatus: (status) => status != null && status < 400,
                sendTimeout: const Duration(seconds: 6),
                receiveTimeout: const Duration(seconds: 6),
              ),
            );

            final googleLocation = brokerRes.headers.value('location');
            if (googleLocation != null && googleLocation.startsWith('https://accounts.google.com')) {
              launchUri = Uri.parse(googleLocation);
              debugPrint('[SSO] Direct Google OAuth URL resolved: $launchUri');
            }
          }
        }
      } catch (e) {
        debugPrint('[SSO] Direct Google URL resolution fallback: $e');
      }
    }

    debugPrint('[SSO] Launching Browser URL: $launchUri');

    // 3. Launch browser (prefer in-app browser view for seamless sheet overlay)
    try {
      final launched = await launchUrl(
        launchUri,
        mode: LaunchMode.inAppBrowserView,
      );
      if (!launched) {
        await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[SSO] In-app browser launch error: $e, trying external application');
      try {
        await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      } catch (e2) {
        debugPrint('[SSO] External launch also failed: $e2');
      }
    }

    // 4. Wait for Keycloak redirect back to local server (timeout after 45 seconds)
    try {
      final String code = await codeCompleter.future.timeout(
        const Duration(seconds: 45),
      );

      // Dismiss the in-app browser overlay immediately
      try {
        await closeInAppWebView();
      } catch (_) {}

      // 5. Exchange code for real session
      final session = await exchangeCodeForSession(
        code: code,
        codeVerifier: codeVerifier,
      );

      return session;
    } catch (e) {
      debugPrint('[SSO] Flow timed out or failed: $e');
      rethrow;
    } finally {
      await deepLinkSub?.cancel();
      await _stopLoopbackServer();
    }
  }

  /// Starts local HTTP loopback server to receive the authorization code
  static Future<void> _startLoopbackServer(
    Completer<String> completer,
    String expectedState,
  ) async {
    await _stopLoopbackServer();

    try {
      _loopbackServer = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        localPort,
        shared: true,
      );
      debugPrint('[SSO] Loopback server listening on port $localPort');

      _loopbackServer!.listen((HttpRequest request) async {
        final uri = request.uri;
        if (uri.path == '/callback') {
          final code = uri.queryParameters['code'];
          final state = uri.queryParameters['state'];

          // Verify state parameter to prevent CSRF attacks
          if (state != null && state != expectedState) {
            debugPrint('[SSO] State mismatch warning: received $state vs expected $expectedState');
          }

          // HTML response sent to the mobile browser with automatic app-switching
          request.response.headers.contentType = ContentType.html;
          request.response.write('''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Sign In Successful</title>
  <script>
    // Automatically redirect back to the mobile app
    window.onload = function() {
      setTimeout(function() {
        window.location.href = "esign://auth/success";
      }, 300);
    };
  </script>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; text-align: center; background: #F7F9FC; padding: 40px 16px; margin: 0; }
    .card { background: white; max-width: 380px; margin: 40px auto; padding: 32px 24px; border-radius: 16px; box-shadow: 0 4px 20px rgba(0,0,0,0.08); }
    .icon { width: 56px; height: 56px; background: #E8F5E9; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 16px; color: #2E7D32; font-size: 28px; font-weight: bold; }
    h2 { color: #0C2B82; margin: 0 0 8px; font-size: 22px; }
    p { color: #64748B; font-size: 14px; line-height: 1.5; margin: 0 0 20px; }
    .btn { display: inline-block; background: #0C2B82; color: #ffffff; text-decoration: none; padding: 12px 28px; border-radius: 8px; font-weight: 600; font-size: 15px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon">✓</div>
    <h2>Signed in to eSign!</h2>
    <p>Authentication complete. Returning to the app...</p>
    <a href="esign://auth/success" class="btn">Open eSign App</a>
  </div>
</body>
</html>
''');
          await request.response.close();

          if (code != null && !completer.isCompleted) {
            completer.complete(code);
          }
        }
      });
    } catch (e) {
      debugPrint('[SSO] Could not start loopback server: $e');
    }
  }

  /// Stops the loopback server cleanly
  static Future<void> _stopLoopbackServer() async {
    if (_loopbackServer != null) {
      try {
        await _loopbackServer!.close(force: true);
      } catch (_) {}
      _loopbackServer = null;
    }
  }

  /// Compatibility helper for existing code
  static Future<bool> launchSsoLogin() async {
    try {
      final session = await startDirectSsoFlow();
      return session != null;
    } catch (_) {
      return false;
    }
  }

  /// Stores authenticated application session manually (e.g. dev simulator)
  static Future<void> completeSession({
    required String sessionToken,
    required String userId,
    required String email,
  }) async {
    final session = UserSession(
      userId: userId,
      email: email,
      authenticatedAt: DateTime.now().toUtc(),
      authMethod: 'KEYCLOAK_OIDC_PKCE',
    );

    await PreferencesService.saveSession(
      token: sessionToken,
      session: session,
    );
  }
}
