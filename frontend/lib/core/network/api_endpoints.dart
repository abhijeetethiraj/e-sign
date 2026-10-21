/// Centralized API endpoint constants for the backend.
class ApiEndpoints {
  /// Base API URL for all services
  static const String baseUrl = 'https://esign-api.cubeone.in/api';

  // User Profile
  static const String me = '/auth/me';

  // Native SMS OTP Authentication
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';

  // Electronic Signing Events & Documents
  static const String signingEvents = '/signing-events';
  static const String documents = '/documents';

  // CubeOne Production SSO & SMS OTP Configuration
  static const String cubeOneOtpUrl = 'https://ssoapi.cubeonebiz.com/api/v2/users/otp';
  static const String cubeOneVerifyOtpUrl = 'https://ssoapi.cubeonebiz.com/api/v2/users/verifyotp';
  static const String cubeOneResetPasswordUrl = 'https://ssoapi.cubeonebiz.com/api/v2/users/resetpassword';
  static const String cubeOneApiKey = '5b2f4b31f524b6603d81dbcaabd8121078d00f1614a294c3207e39951f7054c8';
  static const String cubeOneSource = 'VEZA';
  static const String cubeOneOrigin = 'https://account.cubeonebiz.com';

  // ChsOne Production Login & Search Configuration
  static const String chsoneLoginUrl = 'https://authapi.chsone.in/api/v2/users/login';
  static const String chsoneUserSearchUrl = 'https://authapi.chsone.in/api/v2/users/search';
  static const String cubeOneRegisterUrl = 'https://ssoapi.cubeonebiz.com/api/v2/users';
  static const String chsoneClientId = 'qs_client_8163';
  static const String chsoneClientSecret = 'Pyo8r2TAzt';
  static const String chsoneSource = 'Chsone';
}
