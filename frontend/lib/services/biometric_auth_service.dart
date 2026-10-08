import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Service managing device biometric authentication (Fingerprint, Touch ID, Face ID)
/// to provide physical confirmation and legal non-repudiation when signing.
class BiometricAuthService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Prompts the user to verify their fingerprint or biometric credential before signing.
  /// Returns `true` if authentication succeeded or if device has no biometric hardware.
  static Future<({bool authenticated, String method})> authenticateSigner() async {
    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      final bool isSupported = await _auth.isDeviceSupported();

      if (!canCheck && !isSupported) {
        debugPrint('[Biometric] Device does not support biometrics, skipping');
        return (authenticated: true, method: 'Device Authenticated (No Biometrics)');
      }

      final List<BiometricType> available = await _auth.getAvailableBiometrics();
      String methodLabel = 'Fingerprint / Biometric';
      if (available.contains(BiometricType.fingerprint)) {
        methodLabel = 'Fingerprint (Touch ID / Android)';
      } else if (available.contains(BiometricType.face)) {
        methodLabel = 'Face ID';
      }

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Scan fingerprint to confirm and digitally sign this document',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );

      return (
        authenticated: didAuthenticate,
        method: didAuthenticate ? '$methodLabel Verified' : 'Authentication Cancelled',
      );
    } catch (e) {
      debugPrint('[Biometric] Authentication error: $e');
      // If error or cancelled, return false
      return (authenticated: false, method: 'Error: $e');
    }
  }
}
