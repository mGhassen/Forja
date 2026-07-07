import 'dart:io' show Directory, File;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rust/rust.dart';


class KissKhSubtitleDecryptor {
  static Future<String> decryptBody(String body, {String? sourceUrl}) =>
      runDecryptKisskhBody(body, sourceUrl: sourceUrl);

  static Future<String?> fetchAndDecrypt({
    required String url,
    required int episodeId,
    required String language,
    required String userAgent,
    required String referer,
  }) async {
    try {
      final res = await animeHttp('GET', url, headers: {
        'User-Agent': userAgent,
        'Referer': referer,
        'Accept': '*/*',
      }, timeoutSecs: 15, maxRetries: 0);
      if (res.status != 200) {
        debugPrint('[KissKhSub] HTTP ${res.status} for $url');
        return null;
      }
      final body = res.body;
      debugPrint('[KissKhSub] fetched ${body.length} chars from $url');
      final ext = url.split('?').first.split('.').last.toLowerCase();
      final decoded = (ext == 'srt') ? body : await decryptBody(body, sourceUrl: url);

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
    }
  }
}
