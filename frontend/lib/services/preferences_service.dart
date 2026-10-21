import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_session.dart';

/// Service responsible for persisting and retrieving key-value pairs
/// using SharedPreferences (e.g. JWT tokens, authenticated user session).
class PreferencesService {
  static const String _keyToken = 'auth_token';
  static const String _keyUserId = 'user_id';
  static const String _keyUserEmail = 'user_email';
  static const String _keyAuthTime = 'auth_time';
  static const String _keyAuthMethod = 'auth_method';

  /// Saves the active user session and JWT token to local storage
  static Future<void> saveSession({
    required String token,
    required UserSession session,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyUserId, session.userId);
    await prefs.setString(_keyUserEmail, session.email);
    await prefs.setString(_keyAuthTime, session.authenticatedAt.toIso8601String());
    await prefs.setString(_keyAuthMethod, session.authMethod);
  }

  /// Retrieves the stored JWT token (used by Dio Auth Interceptor)
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  /// Restores the persisted UserSession if previously logged in
  static Future<UserSession?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString(_keyToken);
    final String? userId = prefs.getString(_keyUserId);
    final String? email = prefs.getString(_keyUserEmail);
    final String? authTimeStr = prefs.getString(_keyAuthTime);
    final String? authMethod = prefs.getString(_keyAuthMethod);

    // Token and userId are required to consider a session active
    if (token == null || token.isEmpty || userId == null || userId.isEmpty) {
      return null;
    }

    final String resolvedEmail = (email != null && email.isNotEmpty) ? email : userId;

    final DateTime authTime = authTimeStr != null
        ? (DateTime.tryParse(authTimeStr) ?? DateTime.now().toUtc())
        : DateTime.now().toUtc();

    return UserSession(
      userId: userId,
      email: resolvedEmail,
      authenticatedAt: authTime,
      authMethod: authMethod ?? 'OneSSO Mobile Auth',
    );
  }

  /// Clears stored credentials and session data on logout or account deletion
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyAuthTime);
    await prefs.remove(_keyAuthMethod);
    await prefs.remove('cubeone_active_user_id');
    await prefs.remove('cubeone_active_email');
    await prefs.remove('cubeone_active_otp_type');
    await prefs.remove('cubeone_active_source');
    await prefs.remove('cubeone_is_forgot_password');
  }
}
