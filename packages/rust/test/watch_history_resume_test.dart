import 'package:flutter_test/flutter_test.dart';
import 'package:rust/src/watch_history_resume.dart';

void main() {
  group('isStaleResume', () {
    test('returns false when progress is null or empty', () {
      expect(isStaleResume(null), isFalse);
      expect(isStaleResume({'position': 0, 'updatedAt': 0}), isFalse);
    });

    test('returns true when updatedAt is missing', () {
      expect(isStaleResume({'position': 60_000, 'duration': 3_600_000}), isTrue);
    });

    test('returns false for recent progress', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      expect(
        isStaleResume({
          'position': 60_000,
          'duration': 3_600_000,
          'updatedAt': now,
        }),
        isFalse,
      );
    });

    test('returns true when older than threshold', () {
      final old = DateTime.now()
          .subtract(watchHistoryStaleResumeThreshold + const Duration(days: 1))
          .millisecondsSinceEpoch;
      expect(
        isStaleResume({
          'position': 60_000,
          'duration': 3_600_000,
          'updatedAt': old,
        }),
        isTrue,
      );
    });
  });

  group('hasSavedEpisodePlayback', () {
    test('detects saved methods', () {
      expect(hasSavedEpisodePlayback(null), isFalse);
      expect(hasSavedEpisodePlayback({'method': 'trakt_import'}), isFalse);
      expect(hasSavedEpisodePlayback({'method': 'torrent'}), isTrue);
      expect(hasSavedEpisodePlayback({'method': 'stream'}), isTrue);
      expect(hasSavedEpisodePlayback({'method': 'stremio_direct'}), isTrue);
    });
  });

  group('watchHistoryInt', () {
    test('coerces int and double', () {
      expect(watchHistoryInt(42), 42);
      expect(watchHistoryInt(42.9), 42);
      expect(watchHistoryInt(null), 0);
      expect(watchHistoryInt('x', 7), 7);
    });
  });

  group('resumeStartPositionFromProgress', () {
    test('uses in-progress position only inside 2–85% window', () {
      expect(
        resumeStartPositionFromProgress({'position': 10_000, 'duration': 100_000}),
        const Duration(milliseconds: 10_000),
      );
      expect(
        resumeStartPositionFromProgress({'position': 85_000, 'duration': 100_000}),
        Duration.zero,
      );
      expect(
        resumeStartPositionFromProgress({
          'position': 10_000.0,
          'duration': 100_000.0,
        }),
        const Duration(milliseconds: 10_000),
      );
    });
  });

  group('isWatchFinished', () {
    test('marks finished at 85%', () {
      expect(isWatchFinished(84_999, 100_000), isFalse);
      expect(isWatchFinished(85_000, 100_000), isTrue);
      expect(isWatchFinished(0, 0), isFalse);
    });
  });
}
