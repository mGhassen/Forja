import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/my_list/my_list_merge.dart';
import 'package:forja/features/my_list/providers/my_list_providers.dart';
import 'package:forja/shared/catalog/shell/catalog_legacy_list_item.dart';

void main() {
  group('simklCardItem', () {
    test('maps anime row with anilist id', () {
      final card = simklCardItem({
        '_simklType': 'anime',
        'anime': {
          'title': 'Test Anime',
          'year': 2020,
          'ids': {'anilist': 42, 'tmdb': 99},
        },
      });
      expect(card, isNotNull);
      expect(card!['mediaType'], 'anime');
      expect(card['anilistId'], 42);
      expect(card['tmdbId'], 99);
      expect(card['source'], 'simkl');
    });
  });

  group('mergeLocalHubs', () {
    test('keeps local anime when not in simkl list', () {
      final merged = mergeLocalHubs(
        const [],
        [
          {
            'uniqueId': 'anilist_7',
            'anilistId': 7,
            'mediaType': 'anime',
            'listStatus': 'watching',
            'title': 'Local Anime',
          },
        ],
      );
      expect(merged.length, 1);
      expect(merged.first['anilistId'], 7);
    });

    test('skips duplicate tmdb local when simkl already has tmdb', () {
      final merged = mergeLocalHubs(
        [
          {'tmdbId': 550, 'mediaType': 'movie', 'title': 'Simkl Film'},
        ],
        [
          {
            'uniqueId': 'tmdb_movie_550',
            'tmdbId': 550,
            'mediaType': 'movie',
            'title': 'Local Film',
          },
        ],
      );
      expect(merged.length, 1);
      expect(merged.first['title'], 'Simkl Film');
    });
  });

  group('filterSimklByLocal', () {
    test('hides simkl row when locally removed', () {
      final simkl = [
        {'tmdbId': 1, 'mediaType': 'movie', 'title': 'A'},
      ];
      final filtered = filterSimklByLocal(
        simkl,
        const [],
        'watching',
        {'tmdb_movie_1'},
      );
      expect(filtered, isEmpty);
    });

    test('drops simkl row when local status differs', () {
      final simkl = [
        {'tmdbId': 2, 'mediaType': 'movie', 'title': 'B'},
      ];
      final local = [
        {
          'tmdbId': 2,
          'mediaType': 'movie',
          'listStatus': 'completed',
          'title': 'B',
        },
      ];
      final filtered = filterSimklByLocal(simkl, local, 'watching', {});
      expect(filtered, isEmpty);
    });
  });

  group('catalogMetaFromLegacyListItem', () {
    test('builds tmdb open for stored catalog row', () {
      final meta = catalogMetaFromLegacyListItem({
        'uniqueId': 'catalog_test-hub_99',
        'pluginId': 'test-hub',
        'metaId': 'test-hub:99',
        'title': 'Hub Title',
        'catalogOpen': {
          'surface': 'anime',
          'id': '99',
          'extract': {
            'resolveType': 'anime',
            'panelCategory': 'anime',
            'ctx': {'anilistId': 99},
          },
        },
      });
      expect(meta.open?.surface, 'anime');
      expect(meta.open?.id, '99');
      expect(meta.name, 'Hub Title');
    });
  });

  group('myListItemHideKeys', () {
    test('uses anilist key for anime rows', () {
      final keys = myListItemHideKeys({
        'anilistId': 5,
        'mediaType': 'anime',
      });
      expect(keys, {'anilist_5'});
    });
  });
}
