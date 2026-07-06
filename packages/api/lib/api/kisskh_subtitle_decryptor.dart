import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rust/rust.dart';

class KissKhSubtitleDecryptor {
  static String decryptBody(String body, {String? sourceUrl}) {
    return RustLib.instance.decryptKisskhBody(body, sourceUrl: sourceUrl);
  }

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
