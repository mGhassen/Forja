import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:rust/rust.dart';

class PasteShDecryptor {
  static const _ua =
      'Mozilla/5.0 (Linux; Android 11) AppleWebKit/537.36 (KHTML, like Gecko)';

  static Future<String> decrypt(String urlWithHash) async {
    final hashIdx = urlWithHash.indexOf('#');
    if (hashIdx <= 0) return '';
    final baseUrl = urlWithHash.substring(0, hashIdx);

    final raw = await _httpGetText('$baseUrl.txt');
    if (raw == null || raw.isEmpty) return '';
    return decryptRaw(urlWithHash, raw);
  }

  static String decryptRaw(String urlWithHash, String rawResponse) {
    return ForjaRust.instance.decryptPasteResponse(urlWithHash, rawResponse);
  }

  static Future<String?> _httpGetText(String url) async {
    try {
      final resp = await http
          .get(Uri.parse(url), headers: {'User-Agent': _ua})
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
      return resp.body;
    } catch (e) {
      debugPrint('Decrypt GET failed: $e');
      return null;
    }
  }
}
