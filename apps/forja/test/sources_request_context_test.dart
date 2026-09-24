import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/playback/sources_request_context.dart';
import 'package:forja/shared/playback/stremio_stream_id.dart';
import 'package:forja/shared/engine/runtime/open/legacy_movie_meta.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:rust/rust.dart';

void main() {
  group('buildSourcesRequestContext', () {
    test('merges meta.ids + extract + movie imdb; nuvio needs tmdb', () {
      final meta = MetaItem(
        id: 'hub:1',
        type: 'anime',
        name: 'Test Show',
        ids: const {'anilist': '21', 'tmdb': '123', 'imdb': 'tt0111161'},
        open: const MetaOpen(
          surface: 'anime',
          id: '21',
          extract: MetaOpenExtract(
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
        meta: meta,
        open: meta.open,
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
      final meta = MetaItem(
        id: 'hub:99',
        type: 'anime',
        name: 'No Tmdb',
        ids: const {'anilist': '99'},
        open: const MetaOpen(
          surface: 'anime',
          id: '99',
          extract: MetaOpenExtract(
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
        meta: meta,
        open: meta.open,
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

    test('catalog stremioId tt… stamps imdb for stream addons', () {
      final meta = metaItemFromStremioSearchResult({
        'id': 'tt16478058',
        'type': 'movie',
        'name': 'Best of the Best',
        '_addonBaseUrl': 'https://v3-cinemeta.strem.io/manifest.json',
      });
      final movie = Movie(
        id: 1,
        title: 'Best of the Best',
        posterPath: '',
        backdropPath: '',
        voteAverage: 0,
        releaseDate: '2026',
        overview: '',
        mediaType: 'movie',
        imdbId: 'tt16478058',
      );
      final ctx = buildSourcesRequestContext(
        movie: movie,
        meta: meta,
        open: meta.open,
      );
      expect(ctx.ids['imdb'], 'tt16478058');
      expect(ctx.stremioBag?.hasCustomAddon, isTrue);
      expect(ctx.stremioBag?.customStremioId, 'tt16478058');
      final streamId = resolveStremioStreamIdFromBag(
        bag: ctx.stremioBag!,
        addonManifest: {
          'resources': [
            {
              'name': 'stream',
              'idPrefixes': ['tt'],
            },
          ],
        },
      );
      expect(streamId, 'tt16478058');
    });

    test('drama pack resolveType remaps to movie when meta.tmdbMediaType set', () {
      final meta = MetaItem(
        id: 'hub:film',
        type: 'drama',
        name: 'Test Film',
        tmdbMediaType: 'movie',
        ids: const {'tmdb': '1032863', 'imdb': 'tt22526100'},
        open: const MetaOpen(
          surface: 'drama',
          id: '1',
          extract: MetaOpenExtract(
            resolveType: 'drama',
            panelCategory: 'drama',
            ctx: {'kisskhId': 1},
          ),
        ),
      );
      final movie = Movie(
        id: 1032863,
        imdbId: 'tt22526100',
        title: 'Test Film',
        posterPath: '',
        backdropPath: '',
        voteAverage: 0,
        releaseDate: '2026',
        overview: '',
        mediaType: 'movie',
      );
      final ctx = buildSourcesRequestContext(
        movie: movie,
        meta: meta,
        open: meta.open,
      );
      expect(ctx.engine?.resolveType, 'movie');
      expect(ctx.engine?.panelCategory, 'drama');
      expect(ctx.engine?.tmdbId, '1032863');
      expect(ctx.engine?.ctx['kisskhId'], 1);
      expect(ctx.nuvio?.type, 'movie');
    });

    test('drama without tmdbMediaType defaults engine type to tv', () {
      final meta = MetaItem(
        id: 'hub:show',
        type: 'drama',
        name: 'Test Show',
        ids: const {'tmdb': '281009'},
        open: const MetaOpen(
          surface: 'drama',
          id: '2',
          extract: MetaOpenExtract(
            resolveType: 'drama',
            panelCategory: 'drama',
            ctx: {'kisskhId': 2},
          ),
        ),
      );
      final movie = Movie(
        id: 281009,
        title: 'Test Show',
        posterPath: '',
        backdropPath: '',
        voteAverage: 0,
        releaseDate: '2025',
        overview: '',
        mediaType: 'tv',
      );
      final ctx = buildSourcesRequestContext(
        movie: movie,
        meta: meta,
        open: meta.open,
        season: 1,
        episode: 1,
      );
      expect(ctx.engine?.resolveType, 'tv');
      expect(ctx.engine?.panelCategory, 'drama');
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
