import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../models/signing_event.dart';

/// Service responsible for gathering cryptographic and environmental evidence
/// required by international electronic signature laws (ESIGN, eIDAS, IT Act).
class AuditService {
  /// Fetches the signer's public IP address via a lightweight HTTP lookup.
  /// Falls back to loopback/local address if offline or unresolvable.
  static Future<String> getSignerIpAddress() async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
      );
      final response = await dio.get('https://api.ipify.org?format=json');
      if (response.statusCode == 200 && response.data is Map) {
        final ip = response.data['ip']?.toString();
        if (ip != null && ip.isNotEmpty) {
          debugPrint('[Audit] Signer IP detected: $ip');
          return ip;
        }
      }
    } catch (e) {
      debugPrint('[Audit] Could not retrieve public IP, using fallback: $e');
    }
    return '127.0.0.1 (Local Device)';
  }

  /// Computes the cryptographic SHA-256 hash of the document bytes.
  /// This fingerprint proves the document was not altered after signature.
  static String computeDocumentHash(Uint8List documentBytes) {
    final digest = sha256.convert(documentBytes);
    return digest.toString();
  }

  /// Records the signing event to the backend Express/MySQL audit registry
  /// and optionally triggers automated completion email dispatch.
  static Future<bool> recordSigningEvent(
    SigningEvent event, {
    String? signedDocumentHash,
    Uint8List? signedPdfBytes,
  }) async {
    try {
      final dio = ApiClient().dio;
      final url = ApiEndpoints.signingEvents;
      debugPrint('[Audit] Posting signing event to $url with Bearer token injection');
      final response = await dio.post(
        url,
        data: {
          'signingEventId': event.signingEventId,
          'documentHash': event.documentHash,
          'signedDocumentHash': signedDocumentHash,
          'documentTitle': event.documentTitle,
          'userEmail': event.userEmail,
          'userId': event.userId,
          'ipAddress': event.ipAddress,
          'biometricVerification': event.biometricVerification,
          'authenticationMethod': event.authenticationMethod,
          'signedAt': event.signedAt.toIso8601String(),
          'status': event.status,
          if (signedPdfBytes != null) 'pdfBase64': base64Encode(signedPdfBytes),
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('[Audit] Non-fatal: Could not sync signing event to backend: $e');
      return false;
    }
  }

  /// Verifies a document with the backend by checking its SHA-256 hash
  static Future<({bool verified, String status, Map<String, dynamic>? event, String message})>
      verifyDocument(Uint8List documentBytes) async {
    final String hash = computeDocumentHash(documentBytes);
    try {
      final dio = ApiClient().dio;
      final url = '${ApiEndpoints.signingEvents}/verify/$hash';
      debugPrint('[Audit] Verifying document at $url');
      final response = await dio.get(url);
      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        return (
          verified: data['verified'] == true,
          status: data['status']?.toString() ?? 'VALID_AND_AUTHENTIC',
          event: data['event'] is Map ? (data['event'] as Map<String, dynamic>) : null,
          message: data['message']?.toString() ?? 'Document signature is cryptographically verified.',
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return (
          verified: false,
          status: 'NOT_FOUND_OR_TAMPERED',
          event: null,
          message: 'No matching signing event found. Document may be modified or unrecorded.',
        );
      }
      debugPrint('[Audit] Verification network error: $e');
    } catch (e) {
      debugPrint('[Audit] Verification error: $e');
    }
    return (
      verified: false,
      status: 'VERIFICATION_UNAVAILABLE',
      event: null,
      message: 'Could not connect to verification server.',
    );
  }
}
