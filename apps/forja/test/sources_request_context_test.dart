import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/catalog/kit/sources/sources_request_context.dart';
import 'package:forja/shared/catalog/kit/sources/stremio_stream_id.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:rust/rust.dart';

void main() {
  group('buildSourcesRequestContext', () {
    test('merges meta.ids + extract + movie imdb; nuvio needs tmdb', () {
      final meta = CatalogMetaItem(
        id: 'hub:1',
        type: 'anime',
        name: 'Test Show',
        ids: const {'anilist': '21', 'tmdb': '123', 'imdb': 'tt0111161'},
        open: const CatalogOpen(
          surface: 'anime',
          id: '21',
          extract: CatalogOpenExtract(
            resolveType: 'anime',
            panelCategory: 'anime',
            ctx: {'anilistId': 21},
          ),
        ),
      );
      final movie = Movie(
        id: 21,
        title: 'Test Show',
        posterPath: '',
        backdropPath: '',
        voteAverage: 0,
        releaseDate: '2020-01-01',
        overview: '',
        mediaType: 'tv',
      );
      final ctx = buildSourcesRequestContext(
        movie: movie,
        catalogMeta: meta,
        catalogOpen: meta.open,
        season: 1,
        episode: 2,
      );
      expect(ctx.hasTmdb, isTrue);
      expect(ctx.hasImdb, isTrue);
      expect(ctx.ids['anilist'], '21');
      expect(ctx.engine?.tmdbId, '123');
      expect(ctx.engine?.ctx['anilistId'], 21);
      expect(ctx.nuvio?.tmdbId, '123');
      expect(ctx.torrent?.imdbId, 'tt0111161');
      expect(ctx.torrent?.ids['tmdb'], '123');
    });

    test('without ids.tmdb does not invent tmdb from hub open id', () {
      final meta = CatalogMetaItem(
        id: 'hub:99',
        type: 'anime',
        name: 'No Tmdb',
        ids: const {'anilist': '99'},
        open: const CatalogOpen(
          surface: 'anime',
          id: '99',
          extract: CatalogOpenExtract(
            resolveType: 'anime',
            panelCategory: 'anime',
            ctx: {'anilistId': 99},
          ),
        ),
      );
      final movie = Movie(
        id: 99,
        title: 'No Tmdb',
        posterPath: '',
        backdropPath: '',
        voteAverage: 0,
        releaseDate: '2021',
        overview: '',
        mediaType: 'tv',
      );
      final ctx = buildSourcesRequestContext(
        movie: movie,
        catalogMeta: meta,
        catalogOpen: meta.open,
      );
      expect(ctx.hasTmdb, isFalse);
      expect(ctx.engine?.tmdbId, isNull);
      expect(ctx.nuvio, isNull);
      expect(ctx.torrent?.query, contains('No Tmdb'));
      expect(ctx.ids['anilist'], '99');
    });

    test('legacy movie-only path uses movie.id as tmdb when no catalog', () {
      final movie = Movie(
        id: 550,
        imdbId: 'tt0137523',
        title: 'Fight Club',
        posterPath: '',
        backdropPath: '',
        voteAverage: 0,
        releaseDate: '1999-10-15',
        overview: '',
        mediaType: 'movie',
      );
      final ctx = buildSourcesRequestContext(movie: movie);
      expect(ctx.nuvio?.tmdbId, '550');
      expect(ctx.engine?.tmdbId, '550');
      expect(ctx.hasImdb, isTrue);
    });
  });

  group('resolveStremioStreamId', () {
    test('tt prefix uses imdb from bag', () {
      final id = resolveStremioStreamId(
        ids: const {'imdb': 'tt0111161'},
        addonManifest: {
          'resources': [
            {
              'name': 'stream',
              'idPrefixes': ['tt'],
            },
          ],
        },
        series: false,
      );
      expect(id, 'tt0111161');
    });

    test('anilist prefix picks anilist; tt-only skips without imdb', () {
      final bag = const {'anilist': '21'};
      final anilistId = resolveStremioStreamId(
        ids: bag,
        addonManifest: {
          'idPrefixes': ['anilist'],
        },
        series: false,
      );
      expect(anilistId, '21');

      final skipped = resolveStremioStreamId(
        ids: bag,
        addonManifest: {
          'resources': [
            {
              'name': 'stream',
              'idPrefixes': ['tt'],
            },
          ],
        },
        series: false,
      );
      expect(skipped, isNull);
    });

    test('empty prefixes fall back to imdb', () {
      final id = resolveStremioStreamId(
        ids: const {'imdb': 'tt1'},
        addonManifest: const {},
        series: true,
        season: 2,
        episode: 3,
      );
      expect(id, 'tt1:2:3');
    });
  });
}
