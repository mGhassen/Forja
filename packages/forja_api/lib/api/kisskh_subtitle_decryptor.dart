// kisskh.co subtitle decryptor.
//
// kisskh ships SRT/VTT files where each cue's text body is AES-128-CBC
// encrypted and base64-encoded. The site decrypts client-side via an
// obfuscated CryptoJS bundle. Three key/IV pairs are in rotation, picked
// by the subtitle URL's file extension:
//
//   .srt  → plaintext (no encryption)
//   .txt  → key="8056483646328763"  iv="6852612370185273" (legacy)
//   .txt1 → key="AmSmZVcH93UQUezi"  iv="ReBKWW8cqdjPEnF6" (Feb 2025+)
//   other → key="sWODXX04QRTkHdlZ"  iv="8pwhapJeC4hrS9hO" (default)
//
// Source: kisskh-dl issue #14 + Prudhvi-pln/udb KissKhClient.py
//
// We download the file, decrypt cue-by-cue (lines that aren't valid
// ciphertext are kept verbatim → graceful fallback for partially-encrypted
// or future-rotated subs), write the result to the app's temp directory
// and return a `file://` URI for the player to consume directly.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:forja_rust/src/reference/kisskh_decrypt_dart.dart';
import 'package:path_provider/path_provider.dart';

/// Optional Rust backend — set from app bootstrap when [ForjaEngine] loads.
abstract final class KissKhDecryptBackend {
  static String Function(String body, String? sourceUrl)? decryptBody;
}

class KissKhSubtitleDecryptor {
  /// Decrypt every cue text line in a SRT/VTT body. Index lines, timestamp
  /// lines (`-->`), the `WEBVTT` header and blank separators are kept as-is.
  static String decryptBody(String body, {String? sourceUrl}) {
    final backend = KissKhDecryptBackend.decryptBody;
    if (backend != null) {
      return backend(body, sourceUrl);
    }
    return KissKhDecryptDart.decryptBody(body, sourceUrl: sourceUrl);
  }

  /// Download the subtitle at [url] (with kisskh headers), decrypt it, persist
  /// to the temp directory and return a `file://` URI. Returns null on any
  /// failure so the caller can keep the original remote URL.
  static Future<String?> fetchAndDecrypt({
    required String url,
    required int episodeId,
    required String language,
    required String userAgent,
    required String referer,
  }) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set('User-Agent', userAgent);
      req.headers.set('Referer', referer);
      req.headers.set('Accept', '*/*');
      final res = await req.close().timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        debugPrint('[KissKhSub] HTTP ${res.statusCode} for $url');
        return null;
      }
      final body = await res.transform(utf8.decoder).join();
      debugPrint('[KissKhSub] fetched ${body.length} chars from $url');
      final ext = url.split('?').first.split('.').last.toLowerCase();
      final decoded = (ext == 'srt') ? body : decryptBody(body, sourceUrl: url);

      final tmp = await getTemporaryDirectory();
      final dir = Directory('${tmp.path}/kisskh_subs');
      if (!dir.existsSync()) dir.createSync(recursive: true);

      final safeLang = language.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final ts = DateTime.now().millisecondsSinceEpoch;
      final isVtt = url.toLowerCase().contains('.vtt') ||
          decoded.trimLeft().startsWith('WEBVTT');
      final outExt = isVtt ? 'vtt' : 'srt';
      final file =
          File('${dir.path}/${episodeId}_${safeLang}_$ts.$outExt');
      await file.writeAsString(decoded);
      debugPrint('[KissKhSub] wrote ${file.path} (${decoded.length} chars)');

      return Uri.file(file.path).toString();
    } catch (e, st) {
      debugPrint('[KissKhSub] decrypt failed for $url: $e\n$st');
      return null;
    } finally {
      try {
        client?.close(force: true);
      } catch (_) {}
    }
  }
}
