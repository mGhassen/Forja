import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/hub/legacy_list_item.dart';
import 'package:forja/shared/engine/lists/list_open_binding.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('listOpenIdentityTokens', () {
    test('drama row yields drama token', () {
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
      final open = ListOpenBinding.metaOpenForCandidate(
        item,
        meta,
        const ['drama'],
      );
      expect(open?.surface, 'drama');
      expect(open?.id, '18842');
    });

    test('builds tmdb open for movie hub', () {
      final item = {
        'mediaType': 'movie',
        'tmdbId': 603,
        'title': 'Matrix',
      };
      final meta = metaItemFromLegacyListItem(item);
      final open = ListOpenBinding.metaOpenForCandidate(
        item,
        meta,
        const ['movie'],
      );
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
      expect(
        BookmarkStore().items.single['listStatus'],
        'watching',
      );
    });
  });
}
