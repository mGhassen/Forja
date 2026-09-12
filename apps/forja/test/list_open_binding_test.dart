import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/hub/legacy_list_item.dart';
import 'package:forja/shared/engine/lists/list_open_binding.dart';
import 'package:forja_foundation/protocol/protocol.dart';

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
}
