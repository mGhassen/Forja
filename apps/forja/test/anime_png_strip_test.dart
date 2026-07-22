import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/playback/provider_runtime_config.dart';
import 'package:forja/shared/player/player/utils.dart';

void main() {
  setUp(() {
    ProviderRuntimeConfig.instance.debugSetSnapshot(
      ProviderRuntimeSnapshot.builtins(),
    );
  });

  group('animeHlsNeedsPngStripFor (RFC-044)', () {
    test('megaplay auto strips HLS without CDN host needle', () {
      expect(
        animeHlsNeedsPngStripFor(
          'https://brand-new-cdn.example/abc/master.m3u8',
          sourceKey: 'megaplay',
        ),
        isTrue,
      );
      expect(
        animeHlsNeedsPngStripFor(
          'https://megap.kotocdn.site/abc/master.m3u8',
          sourceKey: 'megaplay',
        ),
        isTrue,
      );
    });

    test('animepahe never strips', () {
      expect(
        animeHlsNeedsPngStripFor(
          'https://vault-99.owocdn.top/stream/99/02/abc/uwu.m3u8',
          sourceKey: 'vidnest:animepahe',
        ),
        isFalse,
      );
      expect(
        animeHlsNeedsPngStripFor(
          'https://vault-99.owocdn.top/stream/99/02/abc/uwu.m3u8',
          sourceKey: 'miruro:kiwi',
        ),
        isFalse,
      );
    });

    test('plain CDN without sourceKey skips', () {
      expect(
        animeHlsNeedsPngStrip('https://cdn.example/video.m3u8'),
        isFalse,
      );
    });

    test('proxy of megaplay HLS still needs strip', () {
      expect(
        animeHlsNeedsPngStripFor(
          'http://127.0.0.1:1/hls-proxy?url=https%3A%2F%2Fbrand-new.example%2Fx%2Fmaster.m3u8&strip=png',
          sourceKey: 'megaplay',
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
