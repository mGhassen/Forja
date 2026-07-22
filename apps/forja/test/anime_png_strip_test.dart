import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/playback/provider_runtime_config.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:rust/rust.dart';

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

  group('animePngStripShouldProxy', () {
    test('auto is content-only', () {
      expect(
        animePngStripShouldProxy(
          mode: AnimePngStripMode.auto,
          contentLooksWrapped: false,
        ),
        isFalse,
      );
      expect(
        animePngStripShouldProxy(
          mode: AnimePngStripMode.auto,
          contentLooksWrapped: true,
        ),
        isTrue,
      );
    });

    test('force always; never never', () {
      expect(
        animePngStripShouldProxy(
          mode: AnimePngStripMode.force,
          contentLooksWrapped: false,
        ),
        isTrue,
      );
      expect(
        animePngStripShouldProxy(
          mode: AnimePngStripMode.never,
          contentLooksWrapped: true,
        ),
        isFalse,
      );
    });
  });

  group('applyAnimePngStripIfNeeded', () {
    const catalog =
        'https://megap.kotocdn.site/abc/def/master.m3u8';

    test('auto + plain segment keeps direct HLS (host needle does not force)',
        () async {
      final base = ProviderRuntimeSnapshot.builtins();
      final megaplay = base.animePlaybackProfiles['megaplay']!;
      ProviderRuntimeConfig.instance.debugSetSnapshot(
        ProviderRuntimeSnapshot(
          schema: base.schema,
          templates: base.templates,
          apis: base.apis,
          webstreamr: base.webstreamr,
          megaplay: base.megaplay,
          miruroOrigins: base.miruroOrigins,
          kisskhMirrors: base.kisskhMirrors,
          cdnRefererRules: base.cdnRefererRules,
          animePlaybackProfiles: {
            ...base.animePlaybackProfiles,
            'megaplay': AnimePlaybackProfile(
              probe: megaplay.probe,
              pngStrip: AnimePngStripMode.auto,
              pngStripHostContains: const ['kotocdn', 'nekostream'],
            ),
          },
        ),
      );
      expect(
        ProviderRuntimeConfig.instance
            .animePlaybackProfile('megaplay')
            .urlNeedsPngStrip(catalog),
        isTrue,
      );

      final out = await applyAnimePngStripIfNeeded(
        StreamSource(
          url: catalog,
          title: 'megaplay',
          type: 'hls',
          providerId: 'megaplay',
        ),
        sourceKey: 'megaplay',
        segmentLooksPngWrapped: (_, __) async => false,
        buildStripProxy: (u, _) =>
            'http://127.0.0.1:9/hls-proxy?url=$u&strip=png',
      );
      expect(out.url, catalog);
      expect(out.url.contains('/hls-proxy'), isFalse);
    });

    test('auto + PNG-wrapped segment routes through strip proxy', () async {
      final out = await applyAnimePngStripIfNeeded(
        StreamSource(
          url: catalog,
          title: 'megaplay',
          type: 'hls',
          providerId: 'megaplay',
          catalogUrl: catalog,
        ),
        sourceKey: 'megaplay',
        segmentLooksPngWrapped: (_, __) async => true,
        buildStripProxy: (u, _) =>
            'http://127.0.0.1:9/hls-proxy?url=${Uri.encodeComponent(u)}&strip=png',
      );
      expect(out.url, contains('/hls-proxy'));
      expect(out.url, contains('strip=png'));
      expect(hlsProxyTargetUrl(out.url), catalog);
      expect(out.catalogUrl, catalog);
      expect(out.providerId, 'megaplay');
    });

    test('never keeps catalog even when sample would say wrapped', () async {
      final out = await applyAnimePngStripIfNeeded(
        StreamSource(
          url: 'https://vault.example/a.m3u8',
          title: 'pahe',
          type: 'hls',
          providerId: 'vidnest:animepahe',
        ),
        sourceKey: 'vidnest:animepahe',
        segmentLooksPngWrapped: (_, __) async => true,
        buildStripProxy: (u, _) =>
            'http://127.0.0.1:9/hls-proxy?url=$u&strip=png',
      );
      expect(out.url, 'https://vault.example/a.m3u8');
    });
  });
}
