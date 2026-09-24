import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja/shared/engine/store/legacy_list_item.dart';
import 'package:forja/shared/engine/runtime/open/legacy_movie_meta.dart';
import 'package:forja/shared/engine/runtime/open/catalog_open.dart';
import 'package:forja/shared/engine/runtime/kit/paint_artifact.dart';
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

    test('stremio surface extract falls back to movie/tv not stremio panel', () {
      const movieOpen = MetaOpen(
        surface: 'stremio',
        id: 'tt16478058',
        extras: {
          'mediaType': 'movie',
          'stremioType': 'movie',
          'stremioAddonBaseUrl': 'https://addon.example/manifest.json',
        },
      );
      expect(movieOpen.effectiveExtract.panelCategory, 'movie');
      expect(movieOpen.effectiveExtract.resolveType, 'movie');

      const tvOpen = MetaOpen(
        surface: 'stremio',
        id: 'tt39473828',
        extras: {
          'mediaType': 'tv',
          'stremioType': 'series',
        },
      );
      expect(tvOpen.effectiveExtract.panelCategory, 'tv');
      expect(tvOpen.effectiveExtract.resolveType, 'tv');
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
      expect(meta.open?.extraString('preferredSourcesKind'), 'stremio');
      expect(meta.type, 'tv');
      expect(meta.open?.effectiveExtract.panelCategory, 'tv');
      expect(meta.ids.containsKey('tmdb'), isFalse);
    });

    test('stremio anime type stamps anime extract and Sources default', () {
      final meta = metaItemFromStremioSearchResult({
        'id': 'anilist:99',
        'type': 'anime',
        'name': 'Anime Title',
        '_addonBaseUrl': 'https://addon.example/manifest.json',
      });
      expect(meta.type, 'anime');
      expect(meta.open?.effectiveExtract.panelCategory, 'anime');
      expect(meta.open?.effectiveExtract.resolveType, 'anime');
      expect(meta.open?.extraString('preferredSourcesKind'), 'stremio');
      expect(meta.open?.extraString('stremioType'), 'anime');
    });

    test('paint metaItemOf uses mediaType not open.surface as type', () {
      final open = {
        'surface': 'stremio',
        'id': 'tt16478058',
        'stremioId': 'tt16478058',
        'stremioType': 'movie',
        'stremioAddonBaseUrl': 'https://v3-cinemeta.strem.io/manifest.json',
        'mediaType': 'movie',
      };
      final item = PackPaintArtifact.metaItemOf(
        props: {
          'title': 'Best of the Best',
          'imageUrl': 'https://cdn.example/p.jpg',
          'mediaType': 'movie',
          'year': '2026',
        },
        open: open,
      );
      expect(item, isNotNull);
      expect(item!.type, 'movie');
      expect(item.tmdbMediaType, 'movie');
      expect(item.open?.surface, 'stremio');
      expect(item.open?.extraString('stremioAddonBaseUrl'),
          'https://v3-cinemeta.strem.io/manifest.json');
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

    test('legacy list engine type uses opaque open surface', () {
      expect(
        legacyListEngineType({
          'mediaType': 'anime',
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
          'open': {
            'surface': 'drama',
            'id': '88',
            'extract': {'resolveType': 'drama', 'panelCategory': 'drama'},
          },
        }),
        'drama',
      );
      // Without open — opaque mediaType only (no pack id inference).
      expect(
        legacyListEngineType({'mediaType': 'anime'}),
        'anime',
      );
      expect(
        legacyListEngineType({'mediaType': 'asian_drama', 'tmdbId': 9}),
        'asian_drama',
      );
      expect(
        legacyListEngineType({'mediaType': 'tv', 'tmdbId': 1396}),
        'tv',
      );
    });

    test('legacy list does not invent hub open from pack ids', () {
      final open = metaOpenFromLegacyListItem({
        'mediaType': 'anime',
        'anilistId': 21,
        'title': 'Test',
      });
      // No stored open → tmdb surface fallback (opaque), not anime invent.
      expect(open.surface, 'tmdb');
    });

    test('stored open wins — no hub scent override of tmdb', () {
      final open = metaOpenFromLegacyListItem({
        'mediaType': 'drama',
        'title': 'My Bias, My Boss',
        'tmdbId': 999,
        'uniqueId': 'catalog_kisskh-hub_18842',
        'open': {
          'surface': 'tmdb',
          'id': '999',
          'extract': {
            'resolveType': 'movie',
            'panelCategory': 'movie',
            'ctx': {'tmdbId': 999},
          },
        },
      });
      expect(open.surface, 'tmdb');
      expect(open.id, '999');
      expect(
        legacyListEngineType({
          'mediaType': 'drama',
          'open': {
            'surface': 'tmdb',
            'id': '999',
            'extract': {'resolveType': 'movie', 'panelCategory': 'movie'},
          },
        }),
        'movie',
      );
    });

    test('detailsEngineTypeForOpen uses opaque surface', () {
      final drama = MetaItem(
        id: '18842',
        type: 'drama',
        name: 'Test',
        open: const MetaOpen(
          surface: 'drama',
          id: '18842',
          extract: MetaOpenExtract(
            resolveType: 'drama',
            panelCategory: 'drama',
          ),
        ),
      );
      expect(detailsEngineTypeForOpen(drama), 'drama');

      final tmdb = MetaItem(
        id: '603',
        type: 'movie',
        name: 'Matrix',
        tmdbMediaType: 'movie',
        open: const MetaOpen(
          surface: 'tmdb',
          id: '603',
          extract: MetaOpenExtract(
            resolveType: 'movie',
            panelCategory: 'movie',
            ctx: {'tmdbId': 603},
          ),
        ),
      );
      expect(detailsEngineTypeForOpen(tmdb), 'movie');
    });

    test('feed-only caller remaps non-tmdb open; details hub keeps itself', () {
      final drama = MetaItem(
        id: '18842',
        type: 'drama',
        name: 'Test',
        open: const MetaOpen(
          surface: 'drama',
          id: '18842',
          extract: MetaOpenExtract(
            resolveType: 'drama',
            panelCategory: 'drama',
          ),
        ),
      );
      expect(
        shouldResolveOpenPluginAwayFromCaller(
          callerHasDetails: false,
          item: drama,
        ),
        isTrue,
      );
      expect(
        shouldResolveOpenPluginAwayFromCaller(
          callerHasDetails: true,
          item: drama,
        ),
        isFalse,
      );

      final tmdb = MetaItem(
        id: '603',
        type: 'movie',
        name: 'Matrix',
        tmdbMediaType: 'movie',
        open: const MetaOpen(
          surface: 'tmdb',
          id: '603',
          extract: MetaOpenExtract(
            resolveType: 'movie',
            panelCategory: 'movie',
            ctx: {'tmdbId': 603},
          ),
        ),
      );
      expect(
        shouldResolveOpenPluginAwayFromCaller(
          callerHasDetails: true,
          item: tmdb,
        ),
        isTrue,
      );
    });
  });
}
