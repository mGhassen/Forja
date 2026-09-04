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

    test('hub play context keeps enriched episode stills for player panel', () {
      final meta = CatalogMetaItem.fromJson({
        'id': 'test-hub:1',
        'type': 'drama',
        'name': 'Test Series',
        'background': 'https://cdn.example/backdrop.jpg',
        'videos': [
          {
            'id': '1',
            'episode': 1,
            'title': 'Episode 1',
            'thumbnail': 'https://image.tmdb.org/t/p/w300/still1.jpg',
          },
          {
            'id': '2',
            'episode': 2,
            'title': 'Pilot Part Two',
            'thumbnail': '/still2.jpg',
          },
        ],
      });
      final ctx = catalogPlayContextFromMeta(meta: meta);
      expect(ctx.hubEpisodes, isNotNull);
      expect(ctx.hubEpisodes!.length, 2);
      expect(
        ctx.hubEpisodes![0].thumbnailUrl,
        'https://image.tmdb.org/t/p/w300/still1.jpg',
      );
      expect(
        ctx.hubEpisodes![1].thumbnailUrl,
        contains('still2.jpg'),
      );
    });

    test('TMDB episode video id does not pin selectedPluginIds', () {
      final meta = CatalogMetaItem.fromJson({
        'id': 'tmdb:tv:215704',
        'type': 'tv',
        'name': 'The Gentlemen',
        'open': {
          'surface': 'tmdb',
          'id': '215704',
          'mediaType': 'tv',
        },
        'videos': [
          {
            'id': '215704:S1E1',
            'episode': 1,
            'season': 1,
            'title': 'Episode 1',
          },
        ],
      });
      final ep = meta.videos.first;
      final ctx = catalogPlayContextFromMeta(
        meta: meta,
        episode: ep,
        season: 1,
        episodeNumber: 1,
      );
      expect(ctx.selectedPluginIds, isNull);
    });

    test('provider-scoped episode video id pins selectedPluginIds', () {
      final meta = CatalogMetaItem.fromJson({
        'id': 'larozaa:ser1',
        'type': 'series',
        'name': 'Test Arabic',
        'open': {
          'surface': 'arabic',
          'id': 'ser1',
          'source': 'larozaa',
        },
        'videos': [
          {
            'id': 'larozaa:999',
            'episode': 1,
            'season': 1,
            'title': 'Episode 1',
          },
        ],
      });
      final ep = meta.videos.first;
      final ctx = catalogPlayContextFromMeta(
        meta: meta,
        episode: ep,
        season: 1,
        episodeNumber: 1,
      );
      expect(ctx.selectedPluginIds, {'larozaa'});
    });
  });
}
