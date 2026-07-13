import 'package:flutter_test/flutter_test.dart';
import 'package:rust/src/playback/videasy_extractor.dart';

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
  });

  test('wingsTitleQueryValue single-encodes for query map', () {
    expect(
      VideasyExtractor.wingsTitleQueryValue('Fight Club'),
      'Fight%20Club',
    );
  });

  test('yearFromReleaseDate returns first four chars', () {
    expect(VideasyExtractor.yearFromReleaseDate('1999-10-15'), '1999');
    expect(VideasyExtractor.yearFromReleaseDate(''), isNull);
  });
}
