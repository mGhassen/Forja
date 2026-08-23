import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/extractors/providers/videasy/videasy_extractor.dart';

void main() {
  test('preferHlsMasterUrl rewrites demuxed child playlists to master', () {
    const child =
        'https://moon.peakstorm.top/vd/abc/index-s2160p-v1-a1.m3u8';
    expect(
      VideasyExtractor.preferHlsMasterUrl(child),
      'https://moon.peakstorm.top/vd/abc/master.m3u8',
    );
    const nested =
        'https://moon.peakstorm.top/vd/abc/sd/91/index-s1080p-v1-a1.m3u8';
    expect(
      VideasyExtractor.preferHlsMasterUrl(nested),
      'https://moon.peakstorm.top/vd/abc/master.m3u8',
    );
    const master = 'https://moon.peakstorm.top/vd/abc/master.m3u8';
    expect(VideasyExtractor.preferHlsMasterUrl(master), master);
  });

  test('sources URL double-encodes title via Uri query builder', () {
    final uri = Uri.https(
      'api.speedracelight.com',
      '/vsrc/sources-with-title',
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
    expect(uri.host, 'api.speedracelight.com');
    expect(uri.path, '/vsrc/sources-with-title');
    expect(uri.query, contains('totalSeasons=2'));
    expect(uri.query, contains('seasonId=1'));
    expect(uri.query, contains('episodeId=1'));
  });

  test('movie sources query still sends seasonId/episodeId defaults', () {
    final uri = Uri.https(
      'api.speedracelight.com',
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

  test('Yoru cdn is first mirror; Cypher is second', () {
    final endpoints = VideasyExtractor.mirrorEndpointsForTest();
    final names = VideasyExtractor.mirrorDisplayNamesForTest();
    expect(endpoints.first, 'cdn');
    expect(names.first, 'Yoru');
    expect(endpoints[1], 'downloader2');
    expect(names[1], 'Cypher');
    expect(names, containsAll(['Breach', 'Neon', 'Vyse', 'Killjoy', 'Fade']));
  });

  test('server chip labels match mirror display names for sniff rotate', () {
    expect(
      VideasyExtractor.serverChipLabels,
      containsAll(VideasyExtractor.mirrorDisplayNamesForTest()),
    );
  });

  test('tv sources query uses cdn path with season fields', () {
    final uri = Uri.https(
      'api.speedracelight.com',
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
}
