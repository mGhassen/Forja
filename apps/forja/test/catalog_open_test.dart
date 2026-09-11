import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja/shared/foundation/blocks/shell/legacy_movie_meta.dart';
import 'package:forja/shared/host/kit/kit_open.dart';
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

    test('tmdbCatalogTypeToken prefers tv media type', () {
      final meta = MetaItem(
        id: 'tmdb:tv:1396',
        type: 'tv',
        name: 'Breaking Bad',
        tmdbMediaType: 'tv',
        ids: const {'tmdb': '1396'},
        open: const MetaOpen(
          surface: 'tmdb',
          id: '1396',
          extras: {'mediaType': 'tv'},
        ),
      );
      expect(tmdbCatalogTypeToken(meta), 'tv');
    });
  });
}
