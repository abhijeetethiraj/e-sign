import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef SmsCodeCallback = void Function(String otp);

/// Native Android SMS Service using direct platform channel BroadcastReceiver.
/// Intercepts any incoming SMS in real-time without requiring Google SMS Retriever app hash.
class NativeSmsService {
  static const MethodChannel _channel = MethodChannel('com.example.frontend/sms');
  static SmsCodeCallback? _onCodeReceived;

  /// Initializes the SMS listener and starts watching for incoming SMS
  static void initialize({required SmsCodeCallback onCodeReceived}) {
    _onCodeReceived = onCodeReceived;
    _channel.setMethodCallHandler(_handleMethodCall);
    startListening();
  }

  /// Requests SMS permissions and registers the native SMS BroadcastReceiver
  static Future<void> startListening() async {
    try {
      await _channel.invokeMethod('requestSmsPermission');
      await _channel.invokeMethod('startSmsListener');
      debugPrint('[NativeSmsService] Started SMS broadcast listener.');
    } catch (e) {
      debugPrint('[NativeSmsService] startListening error: $e');
    }
  }

  /// Stops the native SMS BroadcastReceiver
  static Future<void> stopListening() async {
    try {
      await _channel.invokeMethod('stopSmsListener');
      debugPrint('[NativeSmsService] Stopped SMS broadcast listener.');
    } catch (e) {
      debugPrint('[NativeSmsService] stopListening error: $e');
    }
  }

  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onSmsReceived') {
      final body = call.arguments?.toString() ?? '';
      debugPrint('[NativeSmsService] SMS received: $body');
      // Extract 4-digit code (e.g. "1573 is your one time password (OTP)...")
      final match = RegExp(r'\b\d{4}\b').firstMatch(body);
      if (match != null) {
        final otp = match.group(0)!;
        debugPrint('[NativeSmsService] Extracted OTP: $otp');
        _onCodeReceived?.call(otp);
      }
    }
  }
}
