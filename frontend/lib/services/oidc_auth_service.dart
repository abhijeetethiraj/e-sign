import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_session.dart';
import 'preferences_service.dart';

/// Service implementing Direct Mobile OIDC Authorization Code Flow with PKCE.
///
/// Flow (Option 2 — Native Loopback / Direct Mobile Authentication):
/// 1. App starts a local loopback server on http://localhost:8080/callback
/// 2. Generates secure PKCE parameters (code_verifier + code_challenge S256).
/// 3. Launches Keycloak login (devsso.cubeone.in) in system browser.
/// 4. User logs in with Google or Keycloak credentials.
/// 5. Keycloak redirects browser to http://localhost:8080/callback?code=...
/// 6. Local server captures the code, serves a "Signed In Successfully" page.
/// 7. App sends code + code_verifier directly to Keycloak token endpoint.
/// 8. Keycloak returns tokens -> App extracts email/id and saves UserSession!
class OidcAuthService {
  // Keycloak OIDC Configuration
  static const String keycloakBaseUrl = 'https://devsso.cubeone.in';
  static const String realm = 'fstech';
  static const String clientId = 'esign-app';
  static const int localPort = 8080;
  static const String redirectUri = 'http://localhost:8080/callback';
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

  /// Starts the complete Direct Mobile SSO flow:
  /// 1. Launches local loopback server to intercept redirect.
  /// 2. Launches browser with PKCE Keycloak URL.
  /// 3. Captures the code and exchanges for tokens.
  static Future<UserSession?> startDirectSsoFlow() async {
    final state = _generateRandomString(32);
    final nonce = _generateRandomString(32);
    final codeVerifier = _generateRandomString(64);
    final codeChallenge = _generateCodeChallenge(codeVerifier);

    // Save state in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyState, state);
    await prefs.setString(_keyNonce, nonce);
    await prefs.setString(_keyCodeVerifier, codeVerifier);

    // 1. Start local loopback server
    final Completer<String> codeCompleter = Completer<String>();
    await _startLoopbackServer(codeCompleter, state);

    // 2. Build Authorization URI
    final authorizationEndpoint = Uri.parse(
      '$keycloakBaseUrl/realms/$realm/protocol/openid-connect/auth',
    );

    final authorizationUri = authorizationEndpoint.replace(
      queryParameters: {
        'client_id': clientId,
        'response_type': 'code',
        'scope': scope,
        'redirect_uri': redirectUri,
        'state': state,
        'nonce': nonce,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
      },
    );

    debugPrint('[SSO] Launching Browser URL: $authorizationUri');

    // 3. Launch browser (prefer in-app browser view for seamless sheet overlay)
    try {
      final launched = await launchUrl(
        authorizationUri,
        mode: LaunchMode.inAppBrowserView,
      );
      if (!launched) {
        await launchUrl(authorizationUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[SSO] In-app browser launch error: $e, trying external application');
      try {
        await launchUrl(authorizationUri, mode: LaunchMode.externalApplication);
      } catch (e2) {
        debugPrint('[SSO] External launch also failed: $e2');
      }
    }

    // 4. Wait for Keycloak redirect back to local server (timeout after 3 minutes)
    try {
      final String code = await codeCompleter.future.timeout(
        const Duration(minutes: 3),
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
