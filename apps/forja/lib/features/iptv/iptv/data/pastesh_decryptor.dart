import 'dart:convert';

import 'package:flutter/foundation.dart';
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
    return await decryptRaw(urlWithHash, raw);
  }

  static Future<String> decryptRaw(
      String urlWithHash, String rawResponse) async {
    return runRustIsolate(
      () => RustLib.instance.decryptPasteResponse(urlWithHash, rawResponse),
    );
  }

  static Future<String?> _httpGetText(String url) async {
    try {
      final hdr = jsonEncode({'User-Agent': _ua});
      final raw = await runRustIsolate(
        () => RustLib.instance.httpGetJson(
          url,
          timeoutSecs: 12,
          headersJson: hdr,
        ),
      );
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      if (parsed.containsKey('error')) return null;
      final status = parsed['status'] as int;
      if (status < 200 || status >= 300) return null;
      return parsed['body'] as String?;
    } catch (e) {
      debugPrint('Decrypt GET failed: $e');
      return null;
    }
  }
}
