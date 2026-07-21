import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/player/utils.dart';

void main() {
  group('animeHlsNeedsPngStrip', () {
    test('nekostream / mewstream / ibyteimg need strip', () {
      expect(
        animeHlsNeedsPngStrip(
          'https://9hjkrt.nekostream.site/abc/master.m3u8',
        ),
        isTrue,
      );
      expect(
        animeHlsNeedsPngStrip('https://cdn.mewstream.buzz/x/master.m3u8'),
        isTrue,
      );
      expect(
        animeHlsNeedsPngStrip(
          'https://p16-ad-sg.ibyteimg.com/obj/ad-site-i18n/abc',
        ),
        isTrue,
      );
    });

    test('plain CDN and already-proxied skip', () {
      expect(
        animeHlsNeedsPngStrip('https://cdn.example/video.m3u8'),
        isFalse,
      );
      expect(
        animeHlsNeedsPngStrip(
          'http://127.0.0.1:1234/hls-proxy?url=https%3A%2F%2Fx.m3u8',
        ),
        isFalse,
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

    test('detects Megaplay offset-252 wrap', () {
      final raw = <int>[
        0x89, 0x50, 0x4E, 0x47,
        ...List.filled(248, 0),
        0x47,
        ...List.filled(187, 0),
        0x47,
      ];
      expect(raw.length, 252 + 189);
      expect(pngWrapsMpegTs(raw), isTrue);
    });

    test('pure tiny PNG is not wrapped video', () {
      expect(
        pngWrapsMpegTs([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
        isFalse,
      );
    });
  });
}
