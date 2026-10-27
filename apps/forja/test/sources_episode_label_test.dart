import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/playback/play_context.dart';

void main() {
  group('sourcesEpisodeLabel', () {
    test('null for movies', () {
      expect(
        sourcesEpisodeLabel(mediaType: 'movie', season: 1, episode: 1),
        isNull,
      );
    });

    test('uses extract season when label omitted', () {
      expect(
        sourcesEpisodeLabel(mediaType: 'tv', season: 2, episode: 1),
        'S02E01',
      );
    });

    test('franchise label season overrides media-local extract season', () {
      expect(
        sourcesEpisodeLabel(
          mediaType: 'tv',
          season: 1,
          episode: 1,
          labelSeason: 2,
        ),
        'S02E01',
      );
    });
  });

  group('playbackLoadingEpisodeSubtitle', () {
    test('shows franchise season when passed as season', () {
      expect(
        playbackLoadingEpisodeSubtitle(season: 2, episode: 1),
        'Season 2 · Episode 1',
      );
    });
  });
}
