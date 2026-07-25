import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/playback/playback_stream_guards.dart';

String _jwtWithExp(int expUnix) {
  final header = base64Url
      .encode(utf8.encode('{"alg":"none"}'))
      .replaceAll('=', '');
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'exp': expUnix})))
      .replaceAll('=', '');
  return '$header.$payload.sig';
}

void main() {
  group('isStreamUrlTokenExpired', () {
    test('rejects expired CloudStream token URLs', () {
      final token = _jwtWithExp(1_700_000_000); // 2023
      final url =
          'https://cdn.example/pl/x/master.m3u8?token=$token';
      expect(isStreamUrlTokenExpired(url), isTrue);
      expect(isUnplayableCachedStreamUrl(url), isTrue);
    });

    test('accepts fresh token beyond skew', () {
      final now = DateTime.now().toUtc();
      final exp = now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000;
      final url =
          'https://cdn.example/pl/x/master.m3u8?token=${_jwtWithExp(exp)}';
      expect(isStreamUrlTokenExpired(url, now: now), isFalse);
      expect(isUnplayableCachedStreamUrl(url), isFalse);
    });

    test('rejects within skew window', () {
      final now = DateTime.now().toUtc();
      final exp = now.add(const Duration(seconds: 30)).millisecondsSinceEpoch ~/
          1000;
      final url =
          'https://cdn.example/content/a/b/page-0.html?token=${_jwtWithExp(exp)}';
      expect(
        isStreamUrlTokenExpired(url, now: now, skew: const Duration(minutes: 2)),
        isTrue,
      );
    });

    test('URLs without token are not expired', () {
      expect(
        isStreamUrlTokenExpired('https://cdn.example/index.m3u8'),
        isFalse,
      );
    });
  });

  group('isTorrentStreamUrl - Direct Streaming must reject torrents', () {
    test('magnet links are torrents', () {
      expect(
        isTorrentStreamUrl(
          'magnet:?xt=urn:btih:dd8255ecdd7faa5fb887f54fb303487061a6e1f6&dn=x',
        ),
        isTrue,
      );
      expect(isTorrentStreamUrl('MAGNET:?xt=urn:btih:ABC'), isTrue);
    });

    test('urn:btih anywhere in the URL is a torrent', () {
      expect(isTorrentStreamUrl('https://host/x?hash=urn:btih:abc'), isTrue);
    });

    test('.torrent files are torrents', () {
      expect(isTorrentStreamUrl('https://host/file.torrent'), isTrue);
    });

    test('direct HTTP(S) streams are NOT torrents', () {
      expect(isTorrentStreamUrl('https://cdn.example/stream.m3u8'), isFalse);
      expect(isTorrentStreamUrl('https://cdn.example/movie.mp4'), isFalse);
      expect(isTorrentStreamUrl('http://127.0.0.1:8080/hls/index.m3u8'), isFalse);
      expect(isTorrentStreamUrl(''), isFalse);
    });
  });

  group('isLocalLoopbackPlayUrl / isUnplayableCachedStreamUrl', () {
    test('hls-proxy strip URLs are playable loopback', () {
      const url =
          'http://127.0.0.1:60329/hls-proxy?url=https%3A%2F%2Fx.m3u8&strip=png';
      expect(isLocalLoopbackPlayUrl(url), isTrue);
      expect(isUnplayableCachedStreamUrl(url), isFalse);
    });

    test('unknown loopback stays unplayable', () {
      expect(
        isUnplayableCachedStreamUrl('http://127.0.0.1:9/random'),
        isTrue,
      );
    });
  });
}
