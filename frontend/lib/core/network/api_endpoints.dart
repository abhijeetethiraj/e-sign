import 'package:flutter/foundation.dart';

/// Centralized API endpoint constants for the backend.
class ApiEndpoints {
  // Configurable base URL:
  // - Your Mac's local Wi-Fi IP is 192.168.3.39 (accessible by physical Android phone)
  // - Port 8000 is where the Express backend server is running
  static const String serverHost = '192.168.3.39';
  static const int serverPort = 8000;

  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:$serverPort/api';
    }
    // Works on both wireless physical device and emulator
    return 'http://$serverHost:$serverPort/api';
  }

  // User Profile
  static const String me = '/auth/me';

  // Electronic Signing Events & Documents
  static const String signingEvents = '/signing-events';
  static const String documents = '/documents';
}
