import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja/shared/engine/hub/legacy_list_item.dart';
import 'package:forja/shared/engine/hub/legacy_movie_meta.dart';
import 'package:forja/shared/engine/hub/catalog_open.dart';
import 'package:rust/rust.dart';

void main() {
  group('catalog_open routing', () {
    test('movie/tv resolveType uses hub details', () {
      const open = MetaOpen(
        surface: 'tmdb',
        id: '603',
        extras: {'mediaType': 'movie'},
        extract: MetaOpenExtract(
          resolveType: 'movie',
          panelCategory: 'movie',
          ctx: {'tmdbId': 603},
        ),
      );
      expect(metaOpenUsesKitDetails(open), isTrue);
    });

    test('stremio surface uses hub details', () {
      const open = MetaOpen(
        surface: 'stremio',
        id: 'custom:abc',
        extras: {'stremioAddonBaseUrl': 'https://addon.example/manifest.json'},
      );
      expect(metaOpenUsesKitDetails(open), isTrue);
    });

    test('explicit detailsRoute uses feature escape hatch', () {
      const open = MetaOpen(
        surface: 'tmdb',
        id: '603',
        extras: {'detailsRoute': 'legacy'},
      );
      expect(metaOpenUsesKitDetails(open), isFalse);
    });

    test('stremio search row keeps addon id and catalog addon url', () {
      final meta = metaItemFromStremioSearchResult({
        'id': 'anilist:12345',
        'type': 'series',
        'name': 'Test Anime',
        'poster': 'https://cdn.example/p.jpg',
        '_addonBaseUrl': 'https://addon.example/manifest.json',
        '_addonName': 'Test Addon',
      });
      expect(meta.open?.surface, 'stremio');
      expect(meta.open?.id, 'anilist:12345');
      expect(meta.open?.extraString('stremioAddonBaseUrl'),
          'https://addon.example/manifest.json');
      expect(meta.open?.extraString('stremioId'), 'anilist:12345');
      expect(meta.ids.containsKey('tmdb'), isFalse);
    });

    test('legacy movie meta uses tmdb route not plugin id', () {
      final meta = metaItemFromMovie(
        Movie(
          id: 603,
          title: 'The Matrix',
          posterPath: '/poster.jpg',
          backdropPath: '/backdrop.jpg',
          overview: 'Neo',
          releaseDate: '1999-03-31',
          voteAverage: 8.7,
          mediaType: 'movie',
          imdbId: 'tt0133093',
        ),
      );
      expect(meta.open?.surface, 'tmdb');
      expect(meta.ids['tmdb'], '603');
      expect(meta.ids['imdb'], 'tt0133093');
      expect(tmdbCatalogTypeToken(meta), 'movie');
    });

    test('legacy list row keeps pack tmdb open', () {
      final row = {
        'title': 'The Matrix',
        'tmdbId': 603,
        'mediaType': 'movie',
        'posterPath': '/p.jpg',
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
      expect(meta.open?.surface, 'tmdb');
      expect(meta.open?.id, '603');
      expect(legacyListTmdbId({'tmdbId': 603}), 603);
      expect(legacyListTmdbId({'tmdbId': '603'}), 603);
      expect(tmdbCatalogTypeToken(meta), 'movie');
      expect(legacyListEngineType(row), 'movie');
    });

    test('legacy list engine type routes anime and drama hubs', () {
      expect(
        legacyListEngineType({
          'mediaType': 'anime',
          'anilistId': 42,
          'open': {
            'surface': 'anime',
            'id': '42',
            'extract': {'resolveType': 'anime', 'panelCategory': 'anime'},
          },
        }),
        'anime',
      );
      expect(
        legacyListEngineType({
          'mediaType': 'asian_drama',
          'kisskhId': 88,
          'open': {
            'surface': 'drama',
            'id': '88',
            'extract': {'resolveType': 'drama', 'panelCategory': 'drama'},
          },
        }),
        'drama',
      );
      expect(
        legacyListEngineType({'mediaType': 'anime', 'anilistId': 1}),
        'anime',
      );
      expect(
        legacyListEngineType({'mediaType': 'asian_drama', 'tmdbId': 9}),
        'drama',
      );
      expect(
        legacyListEngineType({'mediaType': 'tv', 'tmdbId': 1396}),
        'tv',
      );
    });

    test('legacy list invents anime open from mediaType when missing', () {
      final open = metaOpenFromLegacyListItem({
        'mediaType': 'anime',
        'anilistId': 21,
        'title': 'Test',
      });
      expect(open.surface, 'anime');
      expect(open.id, '21');
      expect(open.effectiveExtract.resolveType, 'anime');
    });
  });
}
