import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/anime/catalog/anime_service.dart';
import 'package:forja/shared/playback/anime_playback_bridge.dart';
import 'package:rust/rust.dart';
import 'helpers/rust_engine.dart';

void main() {
  setUpAll(() async {
    await initRustForAppTests();
  });

  group('AnimePlaybackBridge.hitsToStreamSources', () {
    test('expands every media.sources server under a Miruro hit', () {
      const embed = AnimeEmbed(
        label: 'AniKoto',
        server: 'miruro',
        category: 'sub',
        url: 'miruro://anilist/1/1/sub/bee',
      );
      final hits = <AnimeResolvedHit>[
        (
          embed: embed,
          media: ExtractedMedia(
            url: 'https://cdn.example/a.m3u8',
            headers: const {'Referer': 'https://www.miruro.tv/'},
            provider: 'miruro',
            sources: [
              StreamSource(
                url: 'https://cdn.example/a.m3u8',
                title: 'VidPlay-1',
                type: 'hls',
                headers: const {'Referer': 'https://www.miruro.tv/'},
              ),
              StreamSource(
                url: 'https://cdn.example/b.m3u8',
                title: 'Vidstream-2',
                type: 'hls',
                headers: const {'Referer': 'https://www.miruro.tv/'},
              ),
              StreamSource(
                url: 'https://cdn.example/c.mp4',
                title: 'VidCloud-1',
                type: 'video',
                headers: const {'Referer': 'https://www.miruro.tv/'},
              ),
            ],
          ),
        ),
      ];
      final sources = AnimePlaybackBridge.hitsToStreamSources(hits);
      expect(sources.map((s) => s.title), [
        'VidPlay-1',
        'Vidstream-2',
        'VidCloud-1',
      ]);
      expect(sources.length, 3);
    });
  });

  group('AnimePlaybackBridge.embedsToPanelProviders', () {
    test('keeps sub and dub as separate panel rows', () {
      const embeds = [
        AnimeEmbed(
          label: 'Megaplay',
          server: 'megaplay',
          category: 'sub',
          url: 'https://megaplay.buzz/stream/s-2/abc/sub',
        ),
        AnimeEmbed(
          label: 'Megaplay',
          server: 'megaplay',
          category: 'dub',
          url: 'https://megaplay.buzz/stream/s-2/abc/dub',
        ),
      ];
      final map = AnimePlaybackBridge.embedsToPanelProviders(embeds);
      expect(map.keys, containsAll(['megaplay:sub', 'megaplay:dub']));
      expect(map.length, 2);
    });
  });

  group('AnimePlaybackBridge.embedsToProviders', () {
    test('uses sourceKey ids for engine ordering', () {
      const embeds = [
        AnimeEmbed(
          label: 'Megaplay',
          server: 'megaplay',
          category: 'sub',
          url: 'https://megaplay.buzz/stream/s-2/abc/sub',
        ),
        AnimeEmbed(
          label: 'Vidwish',
          server: 'vidwish',
          category: 'sub',
          url: 'https://vidwish.live/stream/s-2/abc/sub',
        ),
      ];
      final map = AnimePlaybackBridge.embedsToProviders(embeds);
      expect(map.keys, containsAll(['megaplay', 'vidwish']));
      expect(map.keys, isNot(contains('embed_0')));
    });
  });

  group('anime provider ordering regression', () {
    test('strict megaplay pin resolves when candidate uses sourceKey', () {
      final order = SourceEngine.orderProviders(
        domain: SourceDomain.anime,
        candidateIds: ['megaplay', 'vidwish'],
        preferred: 'megaplay',
        settingsOrder: ['megaplay', 'vidwish'],
      );
      expect(order.orderedIds, ['megaplay']);
    });

    test('auto mode keeps real anime provider keys', () {
      final order = SourceEngine.orderProviders(
        domain: SourceDomain.anime,
        candidateIds: ['megaplay', 'vidwish', 'miruro:bee'],
        settingsOrder: ['megaplay', 'vidwish', 'miruro:bee'],
      );
      expect(order.orderedIds, isNotEmpty);
      expect(order.orderedIds, contains('megaplay'));
    });

    test('synthetic embed_* keys are dropped by source engine', () {
      final order = SourceEngine.orderProviders(
        domain: SourceDomain.anime,
        candidateIds: ['embed_0', 'embed_1'],
        settingsOrder: ['embed_0'],
      );
      expect(order.orderedIds, isEmpty);
    });
  });
}
