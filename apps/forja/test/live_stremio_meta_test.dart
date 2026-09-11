import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/live/stremio_live_meta.dart';

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
        now: DateTime.utc(2026, 8, 1),
      );
      expect(ms, DateTime.utc(2026, 8, 22, 7, 0).millisecondsSinceEpoch);
    });

    test('upcoming same-month range uses start day', () {
      final ms = stremioKickoffMsFromTitleAndTime(
        title: 'Cup Final | 7 – 13 September 2026',
        description: 'Time: 07:10\nChannels: Golf',
        now: DateTime.utc(2026, 9, 1),
      );
      expect(ms, DateTime.utc(2026, 9, 7, 7, 10).millisecondsSinceEpoch);
    });

    test('ongoing range uses today + Time', () {
      final ms = stremioKickoffMsFromTitleAndTime(
        title: 'Solheim Cup | 7 – 13 September 2026',
        description: 'Time: 07:10\nChannels: Golf',
        now: DateTime.utc(2026, 9, 10, 15, 0),
      );
      expect(ms, DateTime.utc(2026, 9, 10, 7, 10).millisecondsSinceEpoch);
    });

    test('cross-month ongoing uses today + Time', () {
      final ms = stremioKickoffMsFromTitleAndTime(
        title: 'US Open | 23 August – 13 September 2026',
        description: 'Time: 11:30\nChannels: ESPN',
        now: DateTime.utc(2026, 9, 10, 12, 0),
      );
      expect(ms, DateTime.utc(2026, 9, 10, 11, 30).millisecondsSinceEpoch);
    });

    test('expired range returns 0', () {
      final ms = stremioKickoffMsFromTitleAndTime(
        title: 'Grand Prix | 4 – 6 September 2026',
        description: 'Time: 11:00',
        now: DateTime.utc(2026, 9, 10),
      );
      expect(ms, 0);
    });

    test('Time only assumes today UTC', () {
      final ms = stremioKickoffMsFromTitleAndTime(
        title: 'Camera Feed 1',
        description: 'Time: 18:30',
        now: DateTime.utc(2026, 9, 10, 12, 0),
      );
      expect(ms, DateTime.utc(2026, 9, 10, 18, 30).millisecondsSinceEpoch);
    });
  });

  group('stremioTitleEventIsOngoing', () {
    test('true inside multi-day window', () {
      expect(
        stremioTitleEventIsOngoing(
          'Solheim Cup | 7 – 13 September 2026',
          now: DateTime.utc(2026, 9, 10),
        ),
        isTrue,
      );
    });

    test('false for single day', () {
      expect(
        stremioTitleEventIsOngoing(
          'Match | 10 September 2026',
          now: DateTime.utc(2026, 9, 10),
        ),
        isFalse,
      );
    });
  });

  group('stremioKickoffMsFromReleaseInfo', () {
    test('parses Highfly Sports Streams day·time UTC', () {
      final ms = stremioKickoffMsFromReleaseInfo('10 Sep 2026 · 16:45 UTC');
      expect(ms, DateTime.utc(2026, 9, 10, 16, 45).millisecondsSinceEpoch);
    });

    test('ignores LIVE label', () {
      expect(stremioKickoffMsFromReleaseInfo('LIVE'), 0);
    });
  });

  group('stremioKickoffIsAiringNow', () {
    test('true inside live window', () {
      final now = DateTime.utc(2026, 9, 10, 17, 0);
      final kick = DateTime.utc(2026, 9, 10, 16, 45).millisecondsSinceEpoch;
      expect(stremioKickoffIsAiringNow(kick, now: now), isTrue);
    });

    test('false before kickoff', () {
      final now = DateTime.utc(2026, 9, 10, 16, 0);
      final kick = DateTime.utc(2026, 9, 10, 16, 45).millisecondsSinceEpoch;
      expect(stremioKickoffIsAiringNow(kick, now: now), isFalse);
    });
  });
}
