import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/screens/utils.dart';
import 'package:rust/rust.dart';

void main() {
  group('hlsNeedsPngStripFor', () {
    test('auto does not force-strip', () {
      expect(
        hlsNeedsPngStripFor(
          'https://cdn.example/abc/master.m3u8',
          pngStrip: 'auto',
        ),
        isFalse,
      );
    });

    test('never does not strip', () {
      expect(
        hlsNeedsPngStripFor(
          'https://cdn.example/stream/uwu.m3u8',
          pngStrip: 'never',
        ),
        isFalse,
      );
    });

    test('missing mode does not strip', () {
      expect(hlsNeedsPngStrip('https://cdn.example/video.m3u8'), isFalse);
    });

    test('force strips an m3u8', () {
      expect(
        hlsNeedsPngStripFor(
          'https://cdn.example/abc/master.m3u8',
          pngStrip: 'force',
        ),
        isTrue,
      );
    });
  });

  group('pngWrapsMpegTs', () {
    test('detects TS after IEND', () {
      final raw = <int>[
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0, 0, 0, 0, 0, 0, 0, 0,
        0x49, 0x45, 0x4E, 0x44, 0, 0, 0, 0,
        0x47,
        ...List.filled(187, 0),
        0x47,
      ];
      expect(pngWrapsMpegTs(raw), isTrue);
    });
  });

  group('applyPngStripIfNeeded', () {
    const catalog = 'https://cdn.example/master.m3u8';

    test('auto leaves the catalog url', () async {
      final out = await applyPngStripIfNeeded(
        StreamSource(
          url: catalog,
          title: 'row',
          type: 'hls',
          pngStrip: 'auto',
        ),
        buildStripProxy: (u, _) =>
            'http://127.0.0.1:9/hls-proxy?url=$u&strip=png',
      );
      expect(out.url, catalog);
    });

    test('force routes through strip proxy', () async {
      final out = await applyPngStripIfNeeded(
        StreamSource(
          url: catalog,
          title: 'row',
          type: 'hls',
          catalogUrl: catalog,
          pngStrip: 'force',
        ),
        buildStripProxy: (u, _) =>
            'http://127.0.0.1:9/hls-proxy?url=${Uri.encodeComponent(u)}&strip=png',
      );
      expect(out.url, contains('/hls-proxy'));
      expect(out.url, contains('strip=png'));
    });
  });
}
