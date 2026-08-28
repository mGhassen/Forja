import 'dart:io' show Directory, File;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rust/rust.dart';


/// KissKh encrypted subtitle fetch + decrypt via `anime/subtitle/kisskh`.
/// Temp file write stays in host (path_provider).
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
      final decoded = await subtitleRequest({
        'action': 'kisskh_fetch_decrypt',
        'url': url,
        'user_agent': userAgent,
        'referer': referer,
      });
      final text = decoded['text'] as String? ?? '';
      if (text.isEmpty) return null;

      final tmp = await getTemporaryDirectory();
      final dir = Directory('${tmp.path}/kisskh_subs');
      if (!dir.existsSync()) dir.createSync(recursive: true);

      final safeLang = language.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final ts = DateTime.now().millisecondsSinceEpoch;
      final isVtt = decoded['is_vtt'] == true;
      final outExt = isVtt ? 'vtt' : 'srt';
      final file = File('${dir.path}/${episodeId}_${safeLang}_$ts.$outExt');
      await file.writeAsString(text);
      debugPrint('[KissKhSub] wrote ${file.path} (${text.length} chars)');

      return Uri.file(file.path).toString();
    } catch (e, st) {
      debugPrint('[KissKhSub] decrypt failed for $url: $e\n$st');
      return null;
    }
  }
}
