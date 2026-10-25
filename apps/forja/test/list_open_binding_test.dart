import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/store/legacy_list_item.dart';
import 'package:forja/shared/engine/store/list_open_bind_sheet.dart';
import 'package:forja/shared/engine/store/list_open_binding.dart';
import 'package:forja/shared/engine/store/list_open_flow.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('listOpenIdentityTokens', () {
    test('drama row yields drama token from open.surface', () {
      final item = {
        'mediaType': 'asian_drama',
        'uniqueId': 'catalog_kisskh-hub_18842',
        'open': {
          'surface': 'drama',
          'id': '18842',
          'extract': {
            'resolveType': 'drama',
            'panelCategory': 'drama',
            'ctx': {'kisskhId': 18842},
          },
        },
      };
      final meta = metaItemFromLegacyListItem(item);
      expect(listOpenIdentityTokens(item, meta), contains('drama'));
      expect(listOpenIdentityTokens(item, meta), isNot(contains('movie')));
    });

    test('tmdb movie row yields movie', () {
      final item = {
        'mediaType': 'movie',
        'tmdbId': 603,
        'open': {
          'surface': 'tmdb',
          'id': '603',
          'extract': {
            'resolveType': 'movie',
            'panelCategory': 'movie',
            'ctx': {'tmdbId': 603},
          },
        },
      };
      final meta = metaItemFromLegacyListItem(item);
      expect(listOpenIdentityTokens(item, meta), contains('movie'));
    });
  });

  group('resolveStored', () {
    test('tmdb open alone is not a stored hub bind', () async {
      final item = {
        'mediaType': 'movie',
        'tmdbId': 603,
        'open': {
          'surface': 'tmdb',
          'id': '603',
          'extract': {
            'resolveType': 'movie',
            'panelCategory': 'movie',
            'ctx': {'tmdbId': 603},
          },
        },
      };
      final meta = metaItemFromLegacyListItem(item);
      expect(
        await ListOpenBinding.resolveStored(item: item, meta: meta),
        isNull,
      );
    });

    test('empty pluginId does not count as stored', () async {
      final item = {
        'pluginId': '  ',
        'mediaType': 'movie',
        'tmdbId': 603,
        'open': {
          'surface': 'tmdb',
          'id': '603',
          'extract': {
            'resolveType': 'movie',
            'panelCategory': 'movie',
            'ctx': {'tmdbId': 603},
          },
        },
      };
      final meta = metaItemFromLegacyListItem(item);
      expect(
        await ListOpenBinding.resolveStored(item: item, meta: meta),
        isNull,
      );
    });
  });

  group('metaOpenForCandidate', () {
    test('keeps drama open for drama hub types', () {
      final item = {
        'mediaType': 'asian_drama',
        'uniqueId': 'catalog_kisskh-hub_18842',
        'open': {
          'surface': 'drama',
          'id': '18842',
          'extract': {
            'resolveType': 'drama',
            'panelCategory': 'drama',
            'ctx': {'kisskhId': 18842},
          },
        },
      };
      final meta = metaItemFromLegacyListItem(item);
      final open = ListOpenBinding.metaOpenForCandidate(item, meta, const [
        'drama',
      ]);
      expect(open?.surface, 'drama');
      expect(open?.id, '18842');
    });

    test('builds tmdb open for movie hub', () {
      final item = {'mediaType': 'movie', 'tmdbId': 603, 'title': 'Matrix'};
      final meta = metaItemFromLegacyListItem(item);
      final open = ListOpenBinding.metaOpenForCandidate(item, meta, const [
        'movie',
      ]);
      expect(open?.surface, 'tmdb');
      expect(open?.id, '603');
    });
  });

  group('persistBinding listStatus', () {
    test('keeps existing bookmark status over default plantowatch', () async {
      SharedPreferences.setMockInitialValues({});
      BookmarkStore().clearForTest();
      await BookmarkStore().upsertMovie(
        tmdbId: 550,
        title: 'Fight Club',
        posterPath: '',
        mediaType: 'movie',
        listStatus: 'completed',
      );

      final item = <String, dynamic>{
        'mediaType': 'movie',
        'tmdbId': 550,
        'title': 'Fight Club',
        // Simkl stub — no listStatus / uniqueId (bug path).
      };
      final meta = metaItemFromLegacyListItem(item);
      final open = MetaOpen(
        surface: 'tmdb',
        id: '550',
        extract: const MetaOpenExtract(
          resolveType: 'movie',
          panelCategory: 'movie',
          ctx: {'tmdbId': 550},
        ),
      );

      await ListOpenBinding.persistBinding(
        item: item,
        pluginId: 'home',
        open: open,
        meta: meta.copyWith(open: open),
      );

      expect(item['listStatus'], 'completed');
      expect(
        BookmarkStore().resolvedStatus(
          uniqueId: BookmarkStore.catalogEntryId('home', '550'),
          tmdbId: 550,
          mediaType: 'movie',
        ),
        'completed',
      );
    });

    test('uses row listStatus when no local bookmark yet', () async {
      SharedPreferences.setMockInitialValues({});
      BookmarkStore().clearForTest();

      final item = <String, dynamic>{
        'mediaType': 'movie',
        'tmdbId': 603,
        'title': 'Matrix',
        'listStatus': 'watching',
      };
      final meta = metaItemFromLegacyListItem(item);
      final open = MetaOpen(
        surface: 'tmdb',
        id: '603',
        extract: const MetaOpenExtract(
          resolveType: 'movie',
          panelCategory: 'movie',
          ctx: {'tmdbId': 603},
        ),
      );

      await ListOpenBinding.persistBinding(
        item: item,
        pluginId: 'home',
        open: open,
        meta: meta.copyWith(open: open),
      );

      expect(item['listStatus'], 'watching');
      expect(BookmarkStore().items.single['listStatus'], 'watching');
    });
  });

  group('kitListUsesOpenBinding', () {
    test('feed-only caller (no details) uses binding', () {
      expect(kitListUsesOpenBinding(callerHasDetails: false), isTrue);
    });

    test('details hub skips binding', () {
      expect(kitListUsesOpenBinding(callerHasDetails: true), isFalse);
      expect(kitListUsesOpenBinding(callerHasDetails: null), isFalse);
    });

    test('offline surface is readable from a feed row', () {
      expect(
        kitListItemSurface({
          'meta': {
            'open': {'surface': 'offline', 'id': 'tt1'},
          },
        }),
        'offline',
      );
    });
  });

  group('kitListOpenRow', () {
    test('lifts nested meta open and title onto the row', () {
      final row = kitListOpenRow({
        'uniqueId': 'catalog_test-hub_1',
        'meta': {
          'id': '1',
          'name': 'Fight Club',
          'poster': 'https://example/p.jpg',
          'type': 'movie',
          'open': {'surface': 'tmdb', 'id': '550'},
        },
      });
      expect(row['open'], isA<Map>());
      expect((row['open'] as Map)['id'], '550');
      expect(row['title'], 'Fight Club');
      expect(row['name'], 'Fight Club');
      expect(row['poster'], 'https://example/p.jpg');
      expect(row['mediaType'], 'movie');
    });
  });

  group('listOpenBindUsesHubSearch', () {
    test('rebind searches a compatible hub', () {
      expect(
        listOpenBindUsesHubSearch(
          pickFilm: true,
          compatible: true,
          hasSearch: true,
        ),
        isTrue,
      );
    });

    test('first open keeps the direct row when the hub already matches', () {
      expect(
        listOpenBindUsesHubSearch(
          pickFilm: false,
          compatible: true,
          hasSearch: true,
        ),
        isFalse,
      );
    });

    test('a hub without search is not a search list', () {
      expect(
        listOpenBindUsesHubSearch(
          pickFilm: true,
          compatible: false,
          hasSearch: false,
        ),
        isFalse,
      );
    });
  });

  group('stampListOpenBinding', () {
    test('writes the saved hub onto the grid row and nested meta', () {
      final saved = {
        'pluginId': 'hub-b',
        'open': {'surface': 'drama', 'id': '9'},
        'metaOpen': {'surface': 'drama', 'id': '9'},
        'catalogOpen': {'surface': 'drama', 'id': '9'},
        'mediaType': 'drama',
        'tmdbId': 4242,
        'tmdbMediaType': 'movie',
        'title': 'Bound Title',
        'name': 'Bound Title',
        'poster': 'https://example/p.jpg',
        'posterPath': 'https://example/p.jpg',
      };
      final grid = {
        'pluginId': 'hub-a',
        'open': {'surface': 'tmdb', 'id': '1'},
        'title': 'Old',
        'poster': 'https://example/old.jpg',
        'meta': {
          'open': {'surface': 'tmdb', 'id': '1'},
          'name': 'Old',
          'poster': 'https://example/old.jpg',
        },
        'paint': {
          'props': {'title': 'Old', 'imageUrl': 'https://example/old.jpg'},
        },
      };
      stampListOpenBinding(saved, grid);
      expect(grid['pluginId'], 'hub-b');
      expect((grid['open'] as Map)['id'], '9');
      expect(((grid['meta'] as Map)['open'] as Map)['surface'], 'drama');
      expect(grid['title'], 'Bound Title');
      expect(grid['poster'], 'https://example/p.jpg');
      expect(grid['tmdbId'], 4242);
      expect(grid['tmdbMediaType'], 'movie');
      expect((grid['meta'] as Map)['name'], 'Bound Title');
      expect((grid['meta'] as Map)['poster'], 'https://example/p.jpg');
      expect(((grid['meta'] as Map)['ids'] as Map)['tmdb'], 4242);
      expect(((grid['paint'] as Map)['props'] as Map)['title'], 'Bound Title');
      expect(
        ((grid['paint'] as Map)['props'] as Map)['imageUrl'],
        'https://example/p.jpg',
      );
    });
  });

  group('persistSimklTmdbLink', () {
    test('sets tmdbId without changing hub open', () async {
      SharedPreferences.setMockInitialValues({});
      BookmarkStore().clearForTest();

      final open = MetaOpen(
        surface: 'drama',
        id: '99',
        extract: const MetaOpenExtract(
          resolveType: 'tv',
          panelCategory: 'drama',
          ctx: {'kisskhId': 99},
        ),
      );
      final item = <String, dynamic>{
        'uniqueId': BookmarkStore.catalogEntryId('hub-arabic-a', '99'),
        'pluginId': 'hub-arabic-a',
        'mediaType': 'drama',
        'listStatus': 'plantowatch',
        'title': 'Arabic Title',
        'open': open.toJson(),
      };
      await BookmarkStore().upsertCatalog(
        pluginId: 'hub-arabic-a',
        open: open.toJson(),
        uniqueId: item['uniqueId'] as String,
        mediaType: 'drama',
        title: 'Arabic Title',
        posterPath: '',
        listStatus: 'plantowatch',
      );

      final hit = MetaItem(
        id: 'tmdb:777',
        type: 'movie',
        name: 'Marnali',
        poster: '',
        ids: const {'tmdb': 777},
        tmdbMediaType: 'movie',
        open: const MetaOpen(
          surface: 'tmdb',
          id: '777',
          extract: MetaOpenExtract(
            resolveType: 'movie',
            panelCategory: 'movie',
            ctx: {'tmdbId': 777},
          ),
        ),
      );

      final ok = await ListOpenBinding.persistSimklTmdbLink(
        item: item,
        hit: hit,
      );
      expect(ok, isTrue);
      expect(item['tmdbId'], 777);
      expect(item['tmdbMediaType'], 'movie');
      expect(item['pluginId'], 'hub-arabic-a');
      expect((item['open'] as Map)['surface'], 'drama');
      expect((item['open'] as Map)['id'], '99');
      final stored = BookmarkStore().itemOf(item['uniqueId'] as String)!;
      expect(stored['tmdbId'], 777);
      expect((stored['open'] as Map)['surface'], 'drama');
    });
  });

  group('persistBinding preserves tmdb', () {
    test('keeps bookmark tmdb when hub hit has none', () async {
      SharedPreferences.setMockInitialValues({});
      BookmarkStore().clearForTest();

      final dramaOpen = MetaOpen(
        surface: 'drama',
        id: '12',
        extract: const MetaOpenExtract(
          resolveType: 'tv',
          panelCategory: 'drama',
          ctx: {'kisskhId': 12},
        ),
      );
      final item = <String, dynamic>{
        'uniqueId': BookmarkStore.catalogEntryId('hub-a', '12'),
        'pluginId': 'hub-a',
        'mediaType': 'drama',
        'tmdbId': 9001,
        'tmdbMediaType': 'movie',
        'listStatus': 'watching',
        'title': 'Local',
        'open': dramaOpen.toJson(),
      };
      await BookmarkStore().upsertCatalog(
        pluginId: 'hub-a',
        open: dramaOpen.toJson(),
        uniqueId: item['uniqueId'] as String,
        mediaType: 'drama',
        title: 'Local',
        posterPath: '',
        listStatus: 'watching',
        tmdbId: 9001,
        tmdbMediaType: 'movie',
      );

      final hubBOpen = MetaOpen(
        surface: 'drama',
        id: '12',
        extract: const MetaOpenExtract(
          resolveType: 'tv',
          panelCategory: 'drama',
          ctx: {'kisskhId': 12},
        ),
      );
      final metaNoTmdb = MetaItem(
        id: 'drama:12',
        type: 'drama',
        name: 'Local',
        poster: '',
        open: hubBOpen,
      );

      await ListOpenBinding.persistBinding(
        item: item,
        pluginId: 'hub-b',
        open: hubBOpen,
        meta: metaNoTmdb,
      );

      expect(item['tmdbId'], 9001);
      expect(BookmarkStore().items.single['tmdbId'], 9001);
      expect(item['pluginId'], 'hub-b');
    });
  });

  group('listPinTargetForBindSheet', () {
    test('synthesizes pin when pluginId missing using fallback hub', () {
      final row = {
        'mediaType': 'movie',
        'tmdbId': 603,
        'listStatus': 'watching',
        'title': 'The Matrix',
        'uniqueId': 'movie:603',
        'open': {
          'surface': 'tmdb',
          'id': '603',
          'extract': {
            'resolveType': 'movie',
            'panelCategory': 'movie',
            'ctx': {'tmdbId': 603},
          },
        },
      };
      final meta = metaItemFromLegacyListItem(row);
      final pin = listPinTargetForBindSheet(
        row: row,
        meta: meta,
        fallbackPluginId: 'hub-fallback',
      );
      expect(pin, isNotNull);
      expect(pin!.pluginId, 'hub-fallback');
      expect(pin.tmdbId, 603);
    });
  });
}
