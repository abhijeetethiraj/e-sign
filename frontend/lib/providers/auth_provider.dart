import 'package:flutter/foundation.dart';
import '../models/user_session.dart';
import '../services/local_document_service.dart';
import '../services/oidc_auth_service.dart';
import '../services/preferences_service.dart';

/// Central state manager for authentication across the application.
/// Provides Keycloak OIDC login, session restoration, and logout.
class AuthProvider extends ChangeNotifier {
  UserSession? _userSession;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;

  // Getters
  bool get isAuthenticated => _userSession != null;
  UserSession? get userSession => _userSession;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;

  /// Restores persisted session from SharedPreferences on app launch
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      _userSession = await PreferencesService.getSession();
    } catch (e) {
      debugPrint('[AuthProvider] Error restoring session: $e');
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Clears any stuck loading state (e.g. if user cancels browser or switches views)
  void cancelLoading() {
    if (_isLoading) {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Initiates Direct Mobile OIDC Authorization Code Flow with PKCE
  Future<bool> initiateSsoLogin({
    String? loginHint,
    String? idpHint,
    bool isRegister = false,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final session = await OidcAuthService.startDirectSsoFlow(
        loginHint: loginHint,
        idpHint: idpHint,
        isRegister: isRegister,
      );
      if (session != null) {
        _userSession = session;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'SSO login failed: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Direct in-app native password authentication (zero browser redirect)
  Future<bool> loginWithCredentials({
    required String username,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final session = await OidcAuthService.loginWithCredentials(
        username: username,
        password: password,
      );
      _userSession = session;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String? _lastSentOtp;
  String? get lastSentOtp => _lastSentOtp;

  /// Checks whether an account exists for the given mobile number or email.
  Future<Map<String, dynamic>> checkUserExists(String identifier) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await OidcAuthService.checkUserExists(identifier);
      return res;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return {'exists': false};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sends a 6-digit SMS verification code via native REST API
  Future<Map<String, dynamic>?> sendSmsOtp(
    String phoneNumber, {
    bool isForgotPassword = false,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await OidcAuthService.sendSmsOtp(
        phoneNumber,
        isForgotPassword: isForgotPassword,
      );
      return result;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Verifies the SMS OTP code natively and establishes the user session
  Future<bool> verifySmsOtp({
    required String phoneNumber,
    required String otp,
    bool? isForgotPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final session = await OidcAuthService.verifySmsOtp(
        phoneNumber: phoneNumber,
        otp: otp,
        isForgotPassword: isForgotPassword,
      );
      _userSession = session;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Temporarily stores verification result from forgot-password OTP flow
  // so the Set Password screen can use it to call resetPassword()
  Map<String, dynamic>? _forgotPasswordData;
  Map<String, dynamic>? get forgotPasswordData => _forgotPasswordData;

  /// Verifies the forgot-password OTP code WITHOUT creating a session.
  /// Stores the auth_code and user_id internally so resetPassword() can use them.
  Future<bool> verifyForgotPasswordOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await OidcAuthService.verifyOtpOnly(
        phoneNumber: phoneNumber,
        otp: otp,
      );
      // Store the verification data for the next step (Set Password screen)
      _forgotPasswordData = result;
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Resets the user's password after OTP verification on the CubeOne backend.
  /// Uses the fp_auth_code stored from verifyForgotPasswordOtp().
  Future<bool> resetPassword({required String newPassword}) async {
    if (_forgotPasswordData == null) {
      _errorMessage = 'Session expired. Please restart the password recovery process.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await OidcAuthService.resetPassword(
        userId: _forgotPasswordData!['user_id']?.toString() ?? '',
        fpAuthCode: _forgotPasswordData!['fp_auth_code']?.toString() ?? '',
        newPassword: newPassword,
        otpType: _forgotPasswordData!['otp_type']?.toString() ?? 'mobile',
        source: _forgotPasswordData!['source']?.toString() ?? 'VEZA',
      );
      _forgotPasswordData = null; // Clean up
      return success;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Creates a new user account without logging in, enabling subsequent OTP verification
  Future<bool> createAccountOnly({
    required String firstName,
    required String lastName,
    required String email,
    required String mobile,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await OidcAuthService.createAccount(
        firstName: firstName,
        lastName: lastName,
        email: email,
        mobile: mobile,
        password: password,
      );
      return success;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Registers a new user and logs them in
  Future<bool> registerUser({
    required String firstName,
    required String lastName,
    required String email,
    required String mobile,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final session = await OidcAuthService.registerUser(
        firstName: firstName,
        lastName: lastName,
        email: email,
        mobile: mobile,
        password: password,
      );
      _userSession = session;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sets the active application session received after authentication
  Future<void> completeSsoSession({
    required String sessionToken,
    required String userId,
    required String email,
  }) async {
    await OidcAuthService.completeSession(
      sessionToken: sessionToken,
      userId: userId,
      email: email,
    );

    _userSession = UserSession(
      userId: userId,
      email: email,
      authenticatedAt: DateTime.now().toUtc(),
      authMethod: 'KEYCLOAK_OIDC_PKCE',
    );
    notifyListeners();
  }

  /// Clears session and local storage
  Future<void> logout() async {
    await PreferencesService.clearSession();
    _userSession = null;
    notifyListeners();
  }

  /// Permanently deletes the account on the backend and purges all documents and session state
  Future<bool> deleteAccount() async {
    _isLoading = true;
    notifyListeners();

    try {
      final currentUserId = _userSession?.userId ?? '';
      if (currentUserId.isNotEmpty) {
        await OidcAuthService.deleteAccount(userId: currentUserId);
      }
      await LocalDocumentService.clearAllDocuments();
      await PreferencesService.clearSession();
      _userSession = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
