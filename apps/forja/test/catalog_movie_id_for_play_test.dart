import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/catalog/kit/meta/catalog_meta_movie.dart';
import 'package:forja/shared/catalog/kit/play/catalog_play_resolve.dart';
import 'package:forja/shared/catalog/protocol.dart';

void main() {
  group('catalogMovieIdForPlay', () {
    test('prefers enrich ids.tmdb over hub open.id', () {
      final meta = CatalogMetaItem.fromJson({
        'id': 'kisskh:13422',
        'type': 'drama',
        'name': 'Test Drama',
        'ids': {'kisskh': '13422', 'tmdb': '999001'},
        'open': {
          'surface': 'drama',
          'id': '13422',
          'extract': {
            'resolveType': 'drama',
            'panelCategory': 'drama',
            'ctx': {'kisskhId': 13422},
          },
        },
      });
      expect(catalogMovieIdForPlay(meta), 999001);
      expect(catalogPlayContextFromMeta(meta: meta).movie.id, 999001);
      expect(meta.open?.idInt, 13422);
    });

    test('falls back to open.id when ids.tmdb missing', () {
      final meta = CatalogMetaItem.fromJson({
        'id': 'kisskh:13422',
        'type': 'drama',
        'name': 'Test Drama',
        'ids': {'kisskh': '13422'},
        'open': {
          'surface': 'drama',
          'id': '13422',
          'extract': {
            'resolveType': 'drama',
            'panelCategory': 'drama',
            'ctx': {'kisskhId': 13422},
          },
        },
      });
      expect(catalogMovieIdForPlay(meta), 13422);
    });

    test('home tmdb open.id still works without ids map', () {
      final meta = CatalogMetaItem.fromJson({
        'id': 'tmdb:tv:1396',
        'type': 'tv',
        'name': 'Breaking Bad',
        'open': {
          'surface': 'tmdb',
          'id': '1396',
          'mediaType': 'tv',
        },
      });
      expect(catalogMovieIdForPlay(meta), 1396);
      expect(catalogMetaToMovie(meta)?.id, 1396);
    });
  });
}
