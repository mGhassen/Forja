import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/anime/catalog/anime_service.dart';
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

  group('AnimeService embeds use runtime config', () {
    test('overlay host appears in buildAllEmbeds', () {
      ProviderRuntimeConfig.instance.debugSetSnapshot(
        ProviderRuntimeSnapshot.builtins().merged(
          ProviderRuntimeSnapshot.tryParse({
            'schema': 1,
            'anime': {
              'megaplay': {'host': 'ops-megaplay.test'},
            },
          })!,
        ),
      );
      final embeds = AnimeService().buildAllEmbeds(
        anilistId: 5114,
        episode: 1,
      );
      final mega = embeds.where((e) => e.server == 'megaplay').toList();
      expect(
        mega.every((e) => e.url.contains('ops-megaplay.test')),
        isTrue,
      );
    });
  });
}
