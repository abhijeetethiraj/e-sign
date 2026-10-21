import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/services/preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthProvider QA Test Suite', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. [Initial State] Starts unauthenticated with null session', () async {
      final authProvider = AuthProvider();
      await authProvider.init();

      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.userSession, isNull);
      expect(authProvider.isLoading, isFalse);
    });

    test('2. [Set Session] Updates userSession and authenticates state via completeSsoSession', () async {
      final authProvider = AuthProvider();
      await authProvider.init();

      await authProvider.completeSsoSession(
        sessionToken: 'mock-jwt-token-12345',
        userId: 'usr_qa_101',
        email: 'tester@esign.corp',
      );

      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.userSession?.email, equals('tester@esign.corp'));
      expect(authProvider.userSession?.userId, equals('usr_qa_101'));
      expect(authProvider.userSession?.authMethod, equals('KEYCLOAK_OIDC_PKCE'));
    });

    test('3. [Session Restoration] Successfully restores saved session from storage', () async {
      // Simulate existing session in persistent storage
      SharedPreferences.setMockInitialValues({
        'auth_token': 'persisted-jwt-token-999',
        'user_id': 'usr_stored_555',
        'user_email': 'returning.signer@esign.corp',
        'auth_time': '2026-10-08T08:00:00.000Z',
        'auth_method': 'Keycloak SSO (Google OAuth2 + PKCE)',
      });

      final authProvider = AuthProvider();
      await authProvider.init();

      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.userSession?.email, equals('returning.signer@esign.corp'));
      expect(authProvider.userSession?.userId, equals('usr_stored_555'));
    });

    test('4. [Logout] Clears session and restores unauthenticated state', () async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'persisted-token',
        'user_id': 'usr_1',
        'user_email': 'user@esign.corp',
        'auth_time': DateTime.now().toIso8601String(),
        'auth_method': 'SSO',
      });

      final authProvider = AuthProvider();
      await authProvider.init();
      expect(authProvider.isAuthenticated, isTrue);

      await authProvider.logout();

      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.userSession, isNull);
    });

    test('5. [Token Persistence] Saves JWT token and verifies availability for ApiClient', () async {
      final authProvider = AuthProvider();
      await authProvider.init();

      await authProvider.completeSsoSession(
        sessionToken: 'eyJhGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.sample_payload.sig',
        userId: 'usr_jwt_user_1',
        email: 'jwt.user@cubeone.in',
      );

      final token = await PreferencesService.getToken();
      expect(token, equals('eyJhGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.sample_payload.sig'));
      expect(authProvider.isAuthenticated, isTrue);
    });
  });
}
