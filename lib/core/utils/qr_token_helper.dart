import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../constants/app_constants.dart';

class QRTokenHelper {
  /// Generates the secure signed payload to encode in the dynamic QR code:
  /// Payload JSON: {"classId": "...", "timestamp": 1234567890, "token": "..."}
  static String generateQRPayload(String classId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final token = generateSignature(classId, timestamp);
    
    final payload = {
      'classId': classId,
      'timestamp': timestamp,
      'token': token,
    };
    
    return jsonEncode(payload);
  }

  /// Calculates the SHA-256 HMAC signature matching the Supabase RPC validation
  static String generateSignature(String classId, int timestamp) {
    final rawString = '$classId:$timestamp:${AppConstants.qrSecretSalt}';
    final bytes = utf8.encode(rawString);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Parses and validates incoming payload structure
  static Map<String, dynamic>? parsePayload(String rawContent) {
    try {
      final decoded = jsonDecode(rawContent);
      if (decoded is Map<String, dynamic> &&
          decoded.containsKey('classId') &&
          decoded.containsKey('timestamp') &&
          decoded.containsKey('token')) {
        return decoded;
      }
    } catch (_) {}
    return null;
  }
}
