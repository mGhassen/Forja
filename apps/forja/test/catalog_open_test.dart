import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/catalog/shell/catalog_legacy_movie_meta.dart';
import 'package:forja/shared/catalog/shell/catalog_open.dart';
import 'package:rust/rust.dart';

void main() {
  group('catalog_open routing', () {
    test('movie/tv resolveType uses hub details', () {
      const open = CatalogOpen(
        surface: 'tmdb',
        id: '603',
        extras: {'mediaType': 'movie'},
        extract: CatalogOpenExtract(
          resolveType: 'movie',
          panelCategory: 'movie',
          ctx: {'tmdbId': 603},
        ),
      );
      expect(catalogOpenUsesHubDetails(open), isTrue);
    });

    test('stremio surface uses hub details', () {
      const open = CatalogOpen(
        surface: 'stremio',
        id: 'custom:abc',
        extras: {'stremioAddonBaseUrl': 'https://addon.example/manifest.json'},
      );
      expect(catalogOpenUsesHubDetails(open), isTrue);
    });

    test('explicit detailsRoute uses feature escape hatch', () {
      const open = CatalogOpen(
        surface: 'tmdb',
        id: '603',
        extras: {'detailsRoute': 'legacy'},
      );
      expect(catalogOpenUsesHubDetails(open), isFalse);
    });

    test('stremio search row keeps addon id and catalog addon url', () {
      final meta = catalogMetaFromStremioSearchResult({
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
      final meta = catalogMetaFromMovie(
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
    });
  });
}
