import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/extractors/providers/videasy/videasy_extractor.dart';

void main() {
  test('wings sources URL double-encodes title via Uri query builder', () {
    final uri = Uri.https(
      'api.wingsdatabase.com',
      '/neon2/sources-with-title',
      VideasyExtractor.sourcesQueryForTest(
        title: 'The Mysterious Benedict Society',
        isMovie: false,
        tmdbId: '104359',
        year: '2021',
        imdbId: 'tt11875316',
        season: 1,
        episode: 1,
        totalSeasons: 2,
        seed: 'test-seed',
      ),
    );
    expect(
      uri.query,
      contains('title=The%2520Mysterious%2520Benedict%2520Society'),
    );
    expect(uri.query, isNot(contains('%252520')));
    expect(uri.host, 'api.wingsdatabase.com');
    expect(uri.path, '/neon2/sources-with-title');
    expect(uri.query, contains('totalSeasons=2'));
    expect(uri.query, contains('seasonId=1'));
    expect(uri.query, contains('episodeId=1'));
  });

  test('movie sources query still sends seasonId/episodeId defaults', () {
    final uri = Uri.https(
      'api.wingsdatabase.com',
      '/cdn/sources-with-title',
      VideasyExtractor.sourcesQueryForTest(
        title: 'Backrooms',
        isMovie: true,
        tmdbId: '1083381',
        year: '2026',
        imdbId: 'tt26657236',
        season: 1,
        episode: 1,
        totalSeasons: null,
        seed: 'test-seed',
      ),
    );
    expect(uri.query, contains('tmdbId=1083381'));
    expect(uri.query, contains('seasonId=1'));
    expect(uri.query, contains('episodeId=1'));
    expect(uri.query, isNot(contains('totalSeasons')));
  });

  test('Yoru cdn is first mirror for movies and TV', () {
    expect(VideasyExtractor.mirrorEndpointsForTest().first, 'cdn');
  });

  test('tv sources query uses cdn path with season fields', () {
    final uri = Uri.https(
      'api.wingsdatabase.com',
      '/cdn/sources-with-title',
      VideasyExtractor.sourcesQueryForTest(
        title: 'Lucky',
        isMovie: false,
        tmdbId: '278624',
        year: '2026',
        imdbId: 'tt34866681',
        season: 1,
        episode: 1,
        totalSeasons: 1,
        seed: 'test-seed',
      ),
    );
    expect(uri.path, '/cdn/sources-with-title');
    expect(uri.query, contains('mediaType=tv'));
    expect(uri.query, contains('totalSeasons=1'));
  });

  test('wingsTitleQueryValue single-encodes for query map', () {
    expect(VideasyExtractor.wingsTitleQueryValue('Fight Club'), 'Fight%20Club');
  });

  test('yearFromReleaseDate returns first four chars', () {
    expect(VideasyExtractor.yearFromReleaseDate('1999-10-15'), '1999');
    expect(VideasyExtractor.yearFromReleaseDate(''), isNull);
  });

  test('grace cutoff keeps streams collected from responsive mirrors', () {
    expect(
      VideasyExtractor.shouldDiscardCollectedHitsForTest(
        hasHits: true,
        cancelled: true,
        graceExpired: true,
      ),
      isFalse,
    );
  });

  test('external cancellation still discards collected mirror streams', () {
    expect(
      VideasyExtractor.shouldDiscardCollectedHitsForTest(
        hasHits: true,
        cancelled: true,
        graceExpired: false,
      ),
      isTrue,
    );
  });

  test('grace cutoff cannot manufacture a result without mirror streams', () {
    expect(
      VideasyExtractor.shouldDiscardCollectedHitsForTest(
        hasHits: false,
        cancelled: true,
        graceExpired: true,
      ),
      isTrue,
    );
  });
}
