import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/player/utils.dart';

void main() {
  group('animeHlsNeedsPngStrip', () {
    test('nekostream / kotocdn / mewstream / ibyteimg need strip', () {
      expect(
        animeHlsNeedsPngStrip(
          'https://9hjkrt.nekostream.site/abc/master.m3u8',
        ),
        isTrue,
      );
      expect(
        animeHlsNeedsPngStrip(
          'https://megap.kotocdn.site/abc/master.m3u8',
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

    test('plain CDN, owocdn (AnimePahe), and unrelated proxy skip', () {
      expect(
        animeHlsNeedsPngStrip('https://cdn.example/video.m3u8'),
        isFalse,
      );
      expect(
        animeHlsNeedsPngStrip(
          'https://vault-99.owocdn.top/stream/99/02/abc/uwu.m3u8',
        ),
        isFalse,
      );
      expect(
        animeHlsNeedsPngStrip(
          'http://127.0.0.1:1234/hls-proxy?url=https%3A%2F%2Fcdn.example%2Fx.m3u8',
        ),
        isFalse,
      );
    });

    test('proxy of nekostream still needs strip', () {
      expect(
        animeHlsNeedsPngStrip(
          'http://127.0.0.1:1/hls-proxy?url=https%3A%2F%2F9hjkrt.nekostream.site%2Fx%2Fmaster.m3u8&strip=png',
        ),
        isTrue,
      );
      expect(
        hlsProxyStripIsPng(
          'http://127.0.0.1:1/hls-proxy?url=https%3A%2F%2Fx.m3u8&strip=png',
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
