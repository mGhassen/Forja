// Dart port of PasteShDecryptor.kt — AES-256-CBC paste.sh blob decoder.
//
// paste.sh stores ciphertext as `Salted__` + 8-byte salt + ciphertext, base64.
// Key/IV are derived from `id + serverkey + clientkey + "https://paste.sh"`,
// using PBKDF2-HMAC-SHA512 (1 iteration → 32-byte key + 16-byte IV).
// Older pastes use OpenSSL EVP_BytesToKey (MD5).
//
// We try PBKDF2 first, fall back to EVP_BytesToKey, and return '' on failure.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:forja_rust/src/reference/pastesh_decrypt_dart.dart';
import 'package:http/http.dart' as http;

/// Optional Rust backend. Set from app bootstrap when [ForjaEngine] loads.
abstract final class PasteShDecryptorBackend {
  static String Function(String urlWithHash, String rawResponse)? decryptRaw;
}

class PasteShDecryptor {
  static const _ua =
      'Mozilla/5.0 (Linux; Android 11) AppleWebKit/537.36 (KHTML, like Gecko)';

  /// `urlWithHash` must include the `#clientkey` fragment.
  /// Returns decrypted plaintext, or '' on any failure.
  static Future<String> decrypt(String urlWithHash) async {
    final hashIdx = urlWithHash.indexOf('#');
    if (hashIdx <= 0) return '';
    final baseUrl = urlWithHash.substring(0, hashIdx);

    final raw = await _httpGetText('$baseUrl.txt');
    if (raw == null || raw.isEmpty) return '';
    return decryptRaw(urlWithHash, raw);
  }

  /// Decrypt paste.sh `.txt` body (no HTTP). Used by Rust delegate path.
  static String decryptRaw(String urlWithHash, String rawResponse) {
    final backend = PasteShDecryptorBackend.decryptRaw;
    if (backend != null) return backend(urlWithHash, rawResponse);
    return PasteShDecryptDart.decryptRaw(urlWithHash, rawResponse);
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
