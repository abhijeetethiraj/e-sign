/// Data model representing the electronic signing audit event per legal specifications.
class SigningEvent {
  final String signingEventId;
  final String userId;
  final String userEmail;
  final String documentTitle;
  final String signatureId;
  final DateTime signedAt;
  final String authenticationMethod;
  final String biometricVerification;
  final String ipAddress;
  final String documentHash;
  final int pageIndex;
  final double x;
  final double y;
  final double width;
  final double height;
  final String status;

  const SigningEvent({
    required this.signingEventId,
    required this.userId,
    required this.userEmail,
    required this.documentTitle,
    required this.signatureId,
    required this.signedAt,
    this.authenticationMethod = 'Keycloak SSO (Google OAuth2 + PKCE)',
    this.biometricVerification = 'Fingerprint (Biometric) Verified',
    required this.ipAddress,
    required this.documentHash,
    required this.pageIndex,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.status = 'COMPLETED',
  });
}
