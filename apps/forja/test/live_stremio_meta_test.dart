import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/live_matches/live_schedule/data/live_stremio_meta.dart';

void main() {
  group('stremioMetaLooksLive', () {
    test('Live TV description is live', () {
      expect(
        stremioMetaLooksLive(
          releaseInfoUpper: '',
          descriptionUpper: 'LIVE TV\nTHEME: ENTERTAINMENT\nCHANNEL ID: 303',
          poster: 'https://example.test/poster.jpg?badge=LIVE',
          genres: ['Live TV'],
        ),
        isTrue,
      );
    });

    test('genre containing LIVE is live', () {
      expect(
        stremioMetaLooksLive(
          releaseInfoUpper: '',
          descriptionUpper: 'CATEGORY: CAMERA FEEDS\nTIME: 18:30',
          poster: '',
          genres: ['Live TV', 'Sports', 'Camera LIVE FEEDS'],
        ),
        isTrue,
      );
    });

    test('Upcoming Events genre is not live', () {
      expect(
        stremioMetaLooksLive(
          releaseInfoUpper: '',
          descriptionUpper: 'CATEGORY: UPCOMING EVENTS\nTIME: 07:00',
          poster: '',
          genres: ['Live TV', 'Sports', 'Upcoming Events'],
        ),
        isFalse,
      );
    });

    test('LIVE NOW description still matches', () {
      expect(
        stremioMetaLooksLive(
          releaseInfoUpper: '',
          descriptionUpper: 'LIVE NOW · FOOTBALL',
          poster: '',
          genres: ['Football'],
        ),
        isTrue,
      );
    });
  });

  group('stremioMetaIsAlwaysOnChannel', () {
    test('Live TV channel row without schedule clock is always-on', () {
      expect(
        stremioMetaIsAlwaysOnChannel(
          looksLive: true,
          dateMs: 0,
          descriptionUpper: 'LIVE TV\nTHEME: ENTERTAINMENT',
          title: 'AMC USA',
          genres: ['Live TV'],
        ),
        isTrue,
      );
    });

    test('live row with Time: clock is not always-on', () {
      expect(
        stremioMetaIsAlwaysOnChannel(
          looksLive: true,
          dateMs: 0,
          descriptionUpper: 'CATEGORY: CAMERA FEEDS\nTIME: 18:30',
          title: 'Camera Feed 1',
          genres: ['Live TV', 'Sports', 'Camera LIVE FEEDS'],
        ),
        isFalse,
      );
    });

    test('live row with calendar date in title is not always-on', () {
      expect(
        stremioMetaIsAlwaysOnChannel(
          looksLive: true,
          dateMs: 0,
          descriptionUpper: 'LIVE TV',
          title: 'Match Day | 22 August 2026',
          genres: ['Live TV'],
        ),
        isFalse,
      );
    });
  });

  group('stremioCategoryFromGenres', () {
    test('skips Live TV / Sports for a specific genre', () {
      expect(
        stremioCategoryFromGenres([
          'Live TV',
          'Sports',
          'Camera LIVE FEEDS',
        ]),
        'Camera LIVE FEEDS',
      );
    });
  });

  group('stremioKickoffMsFromTitleAndTime', () {
    test('parses title date + Time line', () {
      final ms = stremioKickoffMsFromTitleAndTime(
        title: 'Premier League Season | 22 August 2026',
        description: 'Category: Upcoming Events\nTime: 07:00\nChannels: Sky',
      );
      expect(ms, DateTime.utc(2026, 8, 22, 7, 0).millisecondsSinceEpoch);
    });

    test('parses date range start day', () {
      final ms = stremioKickoffMsFromTitleAndTime(
        title: 'Cup Final | 7 – 13 September 2026',
        description: 'Time: 07:10\nChannels: Golf',
      );
      expect(ms, DateTime.utc(2026, 9, 7, 7, 10).millisecondsSinceEpoch);
    });
  });
}
