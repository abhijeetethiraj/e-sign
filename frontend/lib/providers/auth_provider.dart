import 'package:flutter/foundation.dart';
import '../models/user_session.dart';
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

  /// Initiates Direct Mobile OIDC Authorization Code Flow with PKCE
  Future<bool> initiateSsoLogin() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final session = await OidcAuthService.startDirectSsoFlow();
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
}
