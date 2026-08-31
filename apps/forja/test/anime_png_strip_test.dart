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

  group('animeHlsNeedsPngStripFor', () {
    test('auto profile does not strip without force', () {
      expect(
        animeHlsNeedsPngStripFor(
          'https://brand-new-cdn.example/abc/master.m3u8',
          sourceKey: 'megaplay',
        ),
        isFalse,
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
    });

    test('plain CDN without sourceKey skips', () {
      expect(
        animeHlsNeedsPngStrip('https://cdn.example/video.m3u8'),
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
  });

  group('applyAnimePngStripIfNeeded', () {
    const catalog = 'https://megap.kotocdn.site/abc/def/master.m3u8';

    test('auto keeps direct HLS', () async {
      final out = await applyAnimePngStripIfNeeded(
        StreamSource(
          url: catalog,
          title: 'megaplay',
          type: 'hls',
          providerId: 'megaplay',
        ),
        sourceKey: 'megaplay',
        buildStripProxy: (u, _) =>
            'http://127.0.0.1:9/hls-proxy?url=$u&strip=png',
      );
      expect(out.url, catalog);
    });

    test('force routes through strip proxy', () async {
      final base = ProviderRuntimeSnapshot.builtins();
      ProviderRuntimeConfig.instance.debugSetSnapshot(
        ProviderRuntimeSnapshot(
          schema: base.schema,
          templates: base.templates,
          apis: base.apis,
          engine: base.engine,
          sourceHosts: base.sourceHosts,
          megaplay: base.megaplay,
          miruroOrigins: base.miruroOrigins,
          kisskhMirrors: base.kisskhMirrors,
          cdnRefererRules: base.cdnRefererRules,
          animePlaybackProfiles: {
            ...base.animePlaybackProfiles,
            'megaplay': const AnimePlaybackProfile(
              probe: AnimeProbeMode.masterOnly,
              pngStrip: AnimePngStripMode.force,
            ),
          },
        ),
      );

      final out = await applyAnimePngStripIfNeeded(
        StreamSource(
          url: catalog,
          title: 'megaplay',
          type: 'hls',
          providerId: 'megaplay',
          catalogUrl: catalog,
        ),
        sourceKey: 'megaplay',
        buildStripProxy: (u, _) =>
            'http://127.0.0.1:9/hls-proxy?url=${Uri.encodeComponent(u)}&strip=png',
      );
      expect(out.url, contains('/hls-proxy'));
      expect(out.url, contains('strip=png'));
    });
  });
}
