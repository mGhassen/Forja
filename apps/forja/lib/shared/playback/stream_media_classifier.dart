import 'package:flutter/foundation.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:rust/rust.dart';

/// Structural media class from segment bytes / HTTP — never “hostname ⇒ not episode.”
enum StreamMediaClass {
  /// Non-PNG media / MPEG-TS-like sample.
  plainMedia,

  /// PNG shell with MPEG-TS after IEND / offset-252 (or tiny Range decoy).
  pngWrapTs,

  /// Image signature with no TS found in the sample.
  imageNoTs,

  /// Master or segment returned 401/403/404.
  httpBlocked,

  /// Inconclusive.
  unknown,
}

/// Stage 2 of [StreamOpenPipeline] — classify by bytes, not CDN host lists.
abstract final class StreamMediaClassifier {
  /// Classify a raw segment sample (unit-testable).
  static StreamMediaClass classifyBytes(List<int> bytes) {
    if (bytes.isEmpty) return StreamMediaClass.unknown;
    if (looksLikePng(bytes)) {
      if (pngWrapsMpegTs(bytes)) return StreamMediaClass.pngWrapTs;
      // kotocdn Range decoy: tiny PNG while full GET is PNG+TS → strip path.
      if (bytes.length < 512) return StreamMediaClass.pngWrapTs;
      return StreamMediaClass.imageNoTs;
    }
    if (_looksLikeMpegTs(bytes)) return StreamMediaClass.plainMedia;
    return StreamMediaClass.unknown;
  }

  /// Sample HLS master → media playlist → first segments; return decisive class.
  static Future<StreamMediaClass> classifyPlaylist(
    String playlistUrl,
    Map<String, String> headers, {
    @visibleForTesting
    Future<AnimeHttpResult> Function(
      String method,
      String url, {
      Map<String, String>? headers,
      int? maxRetries,
      int? timeoutSecs,
    })? httpGet,
    @visibleForTesting
    Future<List<int>> Function(
      String url, {
      Map<String, String>? headers,
      int? maxRetries,
      int? timeoutSecs,
    })? httpBytes,
  }) async {
    final get = httpGet ??
        (String method, String url, {
          Map<String, String>? headers,
          int? maxRetries,
          int? timeoutSecs,
        }) =>
            animeHttp(
              method,
              url,
              headers: headers ?? const {},
              maxRetries: maxRetries ?? 0,
              timeoutSecs: timeoutSecs ?? 8,
            );
    final bytes = httpBytes ??
        (String url, {
          Map<String, String>? headers,
          int? maxRetries,
          int? timeoutSecs,
        }) =>
            animeHttpBytes(
              url,
              headers: headers ?? const {},
              maxRetries: maxRetries ?? 0,
              timeoutSecs: timeoutSecs ?? 8,
            );

    try {
      final master = await get(
        'GET',
        playlistUrl,
        headers: headers,
        maxRetries: 0,
        timeoutSecs: 8,
      );
      if (master.status == 401 ||
          master.status == 403 ||
          master.status == 404) {
        return StreamMediaClass.httpBlocked;
      }
      if (master.status != 200 || !master.body.contains('#EXTM3U')) {
        return StreamMediaClass.unknown;
      }

      var mediaUrl = playlistUrl;
      var body = master.body;
      final lines = body.split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (!line.startsWith('#EXT-X-STREAM-INF')) continue;
        if (i + 1 >= lines.length) break;
        final next = lines[i + 1].trim();
        if (next.isEmpty || next.startsWith('#')) continue;
        mediaUrl = _join(playlistUrl, next);
        final media = await get(
          'GET',
          mediaUrl,
          headers: headers,
          maxRetries: 0,
          timeoutSecs: 8,
        );
        if (media.status == 401 ||
            media.status == 403 ||
            media.status == 404) {
          return StreamMediaClass.httpBlocked;
        }
        if (media.status != 200 || !media.body.contains('#EXTM3U')) {
          return StreamMediaClass.unknown;
        }
        body = media.body;
        break;
      }

      final segs = body
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && !l.startsWith('#'))
          .map((l) => _join(mediaUrl, l))
          .take(4)
          .toList();
      if (segs.isEmpty) return StreamMediaClass.unknown;

      var pngWrap = 0;
      var imageNoTs = 0;
      var plain = 0;
      var blocked = 0;

      for (final seg in segs) {
        try {
          final res = await get(
            'GET',
            seg,
            headers: {...headers, 'Range': 'bytes=0-2047'},
            maxRetries: 0,
            timeoutSecs: 8,
          );
          if (res.status == 401 ||
              res.status == 403 ||
              res.status == 404) {
            blocked++;
            continue;
          }
          if (res.status != 200 && res.status != 206) continue;

          List<int> sample;
          try {
            sample = await bytes(
              seg,
              headers: {...headers, 'Range': 'bytes=0-2047'},
              maxRetries: 0,
              timeoutSecs: 8,
            );
          } catch (_) {
            continue;
          }
          if (sample.isEmpty) continue;

          switch (classifyBytes(sample)) {
            case StreamMediaClass.pngWrapTs:
              pngWrap++;
            case StreamMediaClass.imageNoTs:
              imageNoTs++;
            case StreamMediaClass.plainMedia:
              plain++;
            case StreamMediaClass.httpBlocked:
              blocked++;
            case StreamMediaClass.unknown:
              break;
          }
        } catch (_) {}
      }

      if (blocked > 0 && pngWrap == 0 && plain == 0 && imageNoTs == 0) {
        return StreamMediaClass.httpBlocked;
      }
      if (pngWrap > 0 && pngWrap >= imageNoTs && pngWrap >= plain) {
        return StreamMediaClass.pngWrapTs;
      }
      if (imageNoTs > 0 && imageNoTs >= plain && imageNoTs > pngWrap) {
        return StreamMediaClass.imageNoTs;
      }
      if (plain > 0) return StreamMediaClass.plainMedia;
      return StreamMediaClass.unknown;
    } catch (_) {
      return StreamMediaClass.unknown;
    }
  }

  static bool _looksLikeMpegTs(List<int> bytes) {
    if (bytes.length < 188 * 2) return false;
    for (var i = 0; i < bytes.length - 188; i++) {
      if (bytes[i] == 0x47 && bytes[i + 188] == 0x47) return true;
    }
    return false;
  }

  static String _join(String base, String uri) {
    final t = uri.trim();
    if (t.startsWith('http://') || t.startsWith('https://')) return t;
    final b = Uri.tryParse(base);
    if (b == null) return t;
    return b.resolve(t).toString();
  }
}
