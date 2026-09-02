import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/my_list/providers/my_list_providers.dart';
import 'package:forja/shared/catalog/kit/sources/my_list/my_list_catalog_source.dart';
import 'package:forja/shared/catalog/kit/sources/my_list/my_list_merge.dart';
import 'package:forja/shared/catalog/shell/catalog_legacy_list_item.dart';

void main() {
  tearDown(clearMyListEnrichCache);

  group('enrichMyListRowsWithCache', () {
    test('reuses cache so status-only rebuilds skip enrich', () async {
      var enrichCalls = 0;
      Future<List<Map<String, dynamic>>> enrich(
        List<Map<String, dynamic>> items,
      ) async {
        enrichCalls++;
        return [
          for (final row in items)
            {...row, 'posterPath': 'https://cdn.example/${row['uniqueId']}.jpg'},
        ];
      }

      final first = await enrichMyListRowsWithCache(
        [
          {
            'uniqueId': 'tmdb_movie_1',
            'tmdbId': 1,
            'mediaType': 'movie',
            'listStatus': 'watching',
            'title': 'A',
          },
        ],
        enrich: enrich,
      );
      expect(enrichCalls, 1);
      expect(first.single['posterPath'], contains('tmdb_movie_1'));

      final second = await enrichMyListRowsWithCache(
        [
          {
            'uniqueId': 'tmdb_movie_1',
            'tmdbId': 1,
            'mediaType': 'movie',
            'listStatus': 'completed',
            'title': 'A',
          },
        ],
        enrich: enrich,
      );
      expect(enrichCalls, 1);
      expect(second.single['listStatus'], 'completed');
      expect(second.single['posterPath'], contains('tmdb_movie_1'));
    });

    test('enriches only cache misses', () async {
      final enrichedIds = <String>[];
      Future<List<Map<String, dynamic>>> enrich(
        List<Map<String, dynamic>> items,
      ) async {
        for (final row in items) {
          enrichedIds.add(row['uniqueId']?.toString() ?? '');
        }
        return [for (final row in items) {...row, 'enriched': true}];
      }

      await enrichMyListRowsWithCache(
        [
          {
            'uniqueId': 'a',
            'mediaType': 'movie',
            'title': 'A',
            'listStatus': 'watching',
          },
        ],
        enrich: enrich,
      );
      final mixed = await enrichMyListRowsWithCache(
        [
          {
            'uniqueId': 'a',
            'mediaType': 'movie',
            'title': 'A',
            'listStatus': 'watching',
          },
          {
            'uniqueId': 'b',
            'mediaType': 'movie',
            'title': 'B',
            'listStatus': 'watching',
          },
        ],
        enrich: enrich,
      );
      expect(enrichedIds, ['a', 'b']);
      expect(mixed.map((e) => e['uniqueId']), ['a', 'b']);
      expect(mixed.every((e) => e['enriched'] == true), isTrue);
    });
  });

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

    test('drops simkl anime when local catalogOpen status differs', () {
      final simkl = [
        {'anilistId': 99, 'mediaType': 'anime', 'title': 'A'},
      ];
      final local = [
        {
          'uniqueId': 'catalog_anime-hub_99',
          'pluginId': 'anime-hub',
          'mediaType': 'anime',
          'listStatus': 'completed',
          'title': 'A',
          'catalogOpen': {'surface': 'anime', 'id': '99'},
        },
      ];
      final filtered = filterSimklByLocal(simkl, local, 'watching', {});
      expect(filtered, isEmpty);
    });

    test('drops simkl when local hold/dropped differs from tab', () {
      final simkl = [
        {'tmdbId': 3, 'mediaType': 'tv', 'title': 'C'},
      ];
      for (final status in ['hold', 'dropped', 'completed']) {
        final local = [
          {
            'tmdbId': 3,
            'mediaType': 'tv',
            'listStatus': status,
            'title': 'C',
          },
        ];
        expect(
          filterSimklByLocal(simkl, local, 'watching', {}),
          isEmpty,
          reason: 'local $status should hide from watching',
        );
      }
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

  group('myListItemKind', () {
    test('splits asian drama from series', () {
      expect(
        myListItemKind({'mediaType': 'asian_drama', 'kisskhId': 9}),
        'asian_drama',
      );
      expect(
        myListItemKind({'mediaType': 'drama', 'title': 'K-drama'}),
        'asian_drama',
      );
      expect(
        myListItemKind({
          'mediaType': 'drama',
          'title': 'Hub drama',
          'catalogOpen': {
            'surface': 'drama',
            'id': '42',
            'extract': {
              'resolveType': 'drama',
              'panelCategory': 'drama',
              'ctx': {'kisskhId': 42},
            },
          },
        }),
        'asian_drama',
      );
      expect(myListItemKind({'mediaType': 'tv', 'tmdbId': 1}), 'tv');
      expect(myListItemKind({'kisskhId': 2, 'mediaType': 'movie'}), 'asian_drama');
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
