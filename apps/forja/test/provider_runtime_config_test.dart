import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/playback/provider_runtime_config.dart';
import 'package:forja/shared/player/player/utils.dart';

void main() {
  tearDown(() {
    ProviderRuntimeConfig.instance.debugReset();
  });

  group('ProviderRuntimeSnapshot', () {
    test('builtins build Megaplay AniList URL', () {
      final url = ProviderRuntimeSnapshot.builtins().megaplay.buildUrl(
        anilistId: 5114,
        episode: 1,
        lang: 'sub',
      );
      expect(url, contains('megaplay.buzz/stream/ani/5114/1/sub'));
    });

    test('merge overlays host + nekostream CDN rule', () {
      final remote = ProviderRuntimeSnapshot.tryParse({
        'schema': 1,
        'anime': {
          'megaplay': {'host': 'megaplay.example'},
          'miruroOrigins': ['https://mirror.example'],
        },
        'cdnRefererRules': [
          {
            'hostContains': ['nekostream'],
            'referer': 'https://megaplay.buzz/',
            'origin': 'https://megaplay.buzz',
            'acceptRefererContains': ['megaplay'],
          },
        ],
      });
      expect(remote, isNotNull);
      final merged =
          ProviderRuntimeSnapshot.builtins().merged(remote!);
      expect(merged.megaplay.host, 'megaplay.example');
      expect(merged.miruroOrigins, ['https://mirror.example']);
      expect(
        merged.megaplay.buildUrl(anilistId: 1, episode: 2, lang: 'dub'),
        contains('megaplay.example/stream/ani/1/2/dub'),
      );
    });

    test('merge overlays engine plugin config at runtime', () {
      final remote = ProviderRuntimeSnapshot.tryParse({
        'schema': 1,
        'engine': {
          'videasy': {
            'api': 'https://overlay.example',
            'mirrors': [
              {'endpoint': 'vsrc', 'name': 'Overlay'},
            ],
          },
        },
      });
      expect(remote, isNotNull);
      final merged = ProviderRuntimeSnapshot.builtins().merged(remote!);
      final videasy = merged.engine['videasy']!;
      expect(videasy['api'], 'https://overlay.example');
      expect(videasy['mirrors'], [
        {'endpoint': 'vsrc', 'name': 'Overlay'},
      ]);
    });

    test('incomplete remote CDN rules keep builtin mewstream/nekostream', () {
      final remote = ProviderRuntimeSnapshot.tryParse({
        'schema': 1,
        'cdnRefererRules': [
          {
            'hostContains': ['mewstream'],
            'referer': 'https://ops.megaplay.test/',
            'origin': 'https://ops.megaplay.test',
            'acceptRefererContains': ['megaplay'],
          },
        ],
      });
      expect(remote, isNotNull);
      final merged =
          ProviderRuntimeSnapshot.builtins().merged(remote!);
      expect(
        merged.cdnRefererRules.any(
          (r) =>
              r.hostContains.contains('mewstream') &&
              r.referer.contains('ops.megaplay.test'),
        ),
        isTrue,
      );
      expect(
        merged.cdnRefererRules.any(
          (r) => r.hostContains.contains('nekostream'),
        ),
        isTrue,
      );
      ProviderRuntimeConfig.instance.debugSetSnapshot(merged);
      final h = resolvePlaybackHttpHeaders(
        null,
        streamUrl: 'https://9hjkrt.nekostream.site/a/b/master.m3u8',
      );
      expect(h['Referer'], 'https://megaplay.buzz/');
    });

    test('builtin Miruro probes: all masterOnly like v1.2.406', () {
      final b = ProviderRuntimeSnapshot.builtins().animePlaybackProfiles;
      expect(b['miruro:zoro']!.probe, AnimeProbeMode.masterOnly);
      expect(b['miruro:bee']!.probe, AnimeProbeMode.masterOnly);
      expect(b['miruro:kiwi']!.probe, AnimeProbeMode.masterOnly);
      expect(b['miruro:ally']!.probe, AnimeProbeMode.masterOnly);
      expect(b['miruro:bonk']!.probe, AnimeProbeMode.masterOnly);
      expect(b['miruro:hop']!.probe, AnimeProbeMode.masterOnly);
      expect(b['miruro:zoro']!.pngStrip, AnimePngStripMode.never);
      expect(b['miruro:bee']!.pngStrip, AnimePngStripMode.never);
    });

    test('builtin KissKh defaults to never strip (pre-df3992cd)', () {
      final b = ProviderRuntimeSnapshot.builtins().animePlaybackProfiles;
      expect(b.containsKey('kisskh'), isFalse);
      ProviderRuntimeConfig.instance.debugSetSnapshot(
        ProviderRuntimeSnapshot.builtins(),
      );
      expect(
        ProviderRuntimeConfig.instance.animePlaybackProfile('kisskh.nl').pngStrip,
        AnimePngStripMode.never,
      );
      expect(
        ProviderRuntimeConfig.instance.animePlaybackProfile('kisskh.co').pngStrip,
        AnimePngStripMode.never,
      );
    });

    test('merge clamps stale remote Miruro segmentPoison to masterOnly', () {
      final remote = ProviderRuntimeSnapshot.tryParse({
        'schema': 1,
        'anime': {
          'playbackProfiles': {
            'miruro:kiwi': {'probe': 'segmentPoisonSample'},
            'miruro:ally': {'probe': 'segmentPoisonSample'},
            'miruro:moo': {'probe': 'segmentPoisonSample'},
            'miruro:bonk': {'probe': 'segmentPoisonSample'},
            'miruro:zoro': {'probe': 'segmentPoisonSample'},
            'miruro:bee': {
              'probe': 'segmentPoisonSample',
              'pngStrip': 'auto',
            },
          },
        },
      });
      expect(remote, isNotNull);
      final merged =
          ProviderRuntimeSnapshot.builtins().merged(remote!);
      for (final k in [
        'miruro:kiwi',
        'miruro:ally',
        'miruro:moo',
        'miruro:bonk',
        'miruro:zoro',
        'miruro:bee',
      ]) {
        expect(
          merged.animePlaybackProfiles[k]!.probe,
          AnimeProbeMode.masterOnly,
          reason: k,
        );
        expect(
          merged.animePlaybackProfiles[k]!.pngStrip,
          AnimePngStripMode.never,
          reason: k,
        );
      }
    });

    test('merge overlays anime playbackProfiles by sourceKey', () {
      final remote = ProviderRuntimeSnapshot.tryParse({
        'schema': 1,
        'anime': {
          'playbackProfiles': {
            'miruro:kiwi': {
              'probe': 'skip',
              'pngStripHostContains': [],
            },
          },
        },
      });
      expect(remote, isNotNull);
      final merged =
          ProviderRuntimeSnapshot.builtins().merged(remote!);
      expect(
        merged.animePlaybackProfiles['miruro:kiwi']!.probe,
        AnimeProbeMode.skip,
      );
      expect(
        merged.animePlaybackProfiles['megaplay']!.probe,
        AnimeProbeMode.segmentPoisonSample,
      );
      expect(
        ProviderRuntimeConfig.instance
            .animePlaybackProfile('miruro:kiwi')
            .probe,
        AnimeProbeMode.masterOnly,
      );
      ProviderRuntimeConfig.instance.debugSetSnapshot(merged);
      expect(
        ProviderRuntimeConfig.instance
            .animePlaybackProfile('miruro:kiwi')
            .probe,
        AnimeProbeMode.skip,
      );
      expect(
        ProviderRuntimeConfig.instance
            .animePlaybackProfile('miruro:kiwi:sub')
            .probe,
        AnimeProbeMode.skip,
      );
      expect(
        animeHlsNeedsPngStripFor(
          'https://vault-99.owocdn.top/x/uwu.m3u8',
          sourceKey: 'miruro:kiwi',
        ),
        isFalse,
      );
      expect(
        animeHlsNeedsPngStripFor(
          'https://9hjkrt.nekostream.site/x/master.m3u8',
          sourceKey: 'megaplay',
        ),
        isTrue,
      );
    });

    test('remote megaplay pngStrip auto without host needles', () {
      final remote = ProviderRuntimeSnapshot.tryParse({
        'schema': 1,
        'anime': {
          'playbackProfiles': {
            'megaplay': {
              'probe': 'segmentPoisonSample',
              'pngStrip': 'auto',
            },
          },
        },
      });
      expect(remote, isNotNull);
      final merged =
          ProviderRuntimeSnapshot.builtins().merged(remote!);
      ProviderRuntimeConfig.instance.debugSetSnapshot(merged);
      expect(
        merged.animePlaybackProfiles['megaplay']!.pngStrip,
        AnimePngStripMode.auto,
      );
      expect(
        animeHlsNeedsPngStripFor(
          'https://brand-new-cdn.example/x/master.m3u8',
          sourceKey: 'megaplay',
        ),
        isTrue,
      );
      expect(
        ProviderRuntimeConfig.instance.playbackPolicyFor('megaplay')?.referer,
        contains('megaplay'),
      );
      expect(
        ProviderRuntimeConfig.instance.playbackPolicyFor('vidfast')?.referer,
        'https://vidfast.vc/',
      );
      expect(
        ProviderRuntimeConfig.instance.playbackPolicyFor('vidzee')?.referer,
        'https://player.vidzee.wtf/',
      );
      expect(
        ProviderRuntimeConfig.instance.playbackPolicyFor('engine:2embed')
            ?.referer,
        'https://play.xpass.top/',
      );
      expect(
        ProviderRuntimeConfig.instance.playbackPolicyFor('engine:meowtv')
            ?.referer,
        'https://meowtv.ru/',
      );
      expect(
        ProviderRuntimeConfig.instance.playbackPolicyFor('miruro:kiwi')?.referer,
        'https://www.miruro.tv/',
      );
    });

    test('unsupported schema ignored', () {
      expect(
        ProviderRuntimeSnapshot.tryParse({'schema': 99, 'anime': {}}),
        isNull,
      );
    });

    test('merge overlays movie template + api base', () {
      final remote = ProviderRuntimeSnapshot.tryParse({
        'schema': 1,
        'templates': {
          'vidlink': {'movie': 'https://ops.test/movie/{tmdb}'},
        },
        'apis': {'vidnestApi': 'https://ops-vidnest.test'},
      });
      expect(remote, isNotNull);
      final merged =
          ProviderRuntimeSnapshot.builtins().merged(remote!);
      expect(
        merged.templates['vidlink']!.movie,
        'https://ops.test/movie/{tmdb}',
      );
      expect(
        merged.templates['vidlink']!.tv,
        contains('vidlink.pro/tv/'),
      );
      expect(merged.apis['vidnestApi'], 'https://ops-vidnest.test');
      expect(merged.apis['anikotoApi'], contains('anikotoapi'));
    });

    test('merge overlays webstreamr hosts', () {
      final remote = ProviderRuntimeSnapshot.tryParse({
        'schema': 1,
        'webstreamr': {'kinoger': 'https://ops-kinoger.test'},
      });
      expect(remote, isNotNull);
      final merged =
          ProviderRuntimeSnapshot.builtins().merged(remote!);
      expect(merged.webstreamr['kinoger'], 'https://ops-kinoger.test');
      expect(merged.webstreamr['cuevana'], contains('cuevana'));
    });
  });

  group('resolvePlaybackHttpHeaders + runtime CDN rules', () {
    test('nekostream forces megaplay Referer from builtins', () {
      const url =
          'https://9hjkrt.nekostream.site/abc/def/master.m3u8';
      final h = resolvePlaybackHttpHeaders(null, streamUrl: url);
      expect(h['Referer'], 'https://megaplay.buzz/');
      expect(h['Origin'], 'https://megaplay.buzz');
    });

    test('remote CDN hostContains can retarget Referer', () {
      ProviderRuntimeConfig.instance.debugSetSnapshot(
        ProviderRuntimeSnapshot.builtins().merged(
          ProviderRuntimeSnapshot.tryParse({
            'schema': 1,
            'cdnRefererRules': [
              {
                'hostContains': ['customcdn'],
                'referer': 'https://megaplay.buzz/',
                'origin': 'https://megaplay.buzz',
                'acceptRefererContains': ['megaplay'],
              },
            ],
          })!,
        ),
      );
      final h = resolvePlaybackHttpHeaders(
        null,
        streamUrl: 'https://x.customcdn.test/a/master.m3u8',
      );
      expect(h['Referer'], 'https://megaplay.buzz/');
    });
  });
}
