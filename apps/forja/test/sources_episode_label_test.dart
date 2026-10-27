import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/playback/play_context.dart';

void main() {
  group('sourcesSeasonCodeFromLabel', () {
    test('Season N', () {
      expect(sourcesSeasonCodeFromLabel('Season 2'), 'S02');
      expect(sourcesSeasonCodeFromLabel('Season 2 - Part 1'), 'S02');
    });

    test('OVA / Special', () {
      expect(sourcesSeasonCodeFromLabel('OVA 1'), 'OVA01');
      expect(sourcesSeasonCodeFromLabel('Special 2'), 'SPECIAL02');
    });
  });

  group('sourcesEpisodeLabel', () {
    test('null for movies', () {
      expect(
        sourcesEpisodeLabel(mediaType: 'movie', season: 1, episode: 1),
        isNull,
      );
    });

    test('uses extract season when pack label omitted', () {
      expect(
        sourcesEpisodeLabel(mediaType: 'tv', season: 2, episode: 1),
        'S02E01',
      );
    });

    test('Season chip ignores rail index', () {
      expect(
        sourcesEpisodeLabel(
          mediaType: 'tv',
          season: 1,
          episode: 1,
          seasonLabel: 'Season 2',
        ),
        'S02E01',
      );
    });

    test('OVA / Special chip codes', () {
      expect(
        sourcesEpisodeLabel(
          mediaType: 'tv',
          season: 1,
          episode: 1,
          seasonLabel: 'OVA 1',
        ),
        'OVA01E01',
      );
      expect(
        sourcesEpisodeLabel(
          mediaType: 'tv',
          season: 1,
          episode: 3,
          seasonLabel: 'Special 1',
        ),
        'SPECIAL01E03',
      );
    });
  });

  group('playbackLoadingEpisodeSubtitle', () {
    test('uses pack chip label when set', () {
      expect(
        playbackLoadingEpisodeSubtitle(
          season: 1,
          episode: 1,
          seasonLabel: 'OVA 1',
        ),
        'OVA 1 · Episode 1',
      );
    });
  });
}
