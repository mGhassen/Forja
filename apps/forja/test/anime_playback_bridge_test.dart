import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/anime/catalog/anime_service.dart';
import 'package:forja/shared/playback/anime_playback_bridge.dart';
import 'package:rust/rust.dart';
import 'helpers/rust_engine.dart';

void main() {
  setUpAll(() async {
    await initRustForAppTests();
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
