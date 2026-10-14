/// Model representing an authenticated user session
class UserSession {
  final String userId;
  final String email;
  final DateTime authenticatedAt;
  final String authMethod;

  const UserSession({
    required this.userId,
    required this.email,
    required this.authenticatedAt,
    this.authMethod = 'Keycloak SSO (Google OAuth2 + PKCE)',
  });

  String get displayName {
    if (email.contains('@')) {
      return email.split('@').first;
    }
    return email;
  }
}
