import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/playback/playback_stream_guards.dart';

void main() {
  group('isTorrentStreamUrl — Direct Streaming must reject torrents', () {
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
}
