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

  group('hasResumableEpisodeProgress', () {
    test('matches isInProgressResume window', () {
      expect(hasResumableEpisodeProgress(null), isFalse);
      expect(
        hasResumableEpisodeProgress({'position': 1000, 'duration': 100_000}),
        isFalse,
      );
      expect(
        hasResumableEpisodeProgress({'position': 10_000, 'duration': 100_000}),
        isTrue,
      );
      expect(
        hasResumableEpisodeProgress({'position': 95_000, 'duration': 100_000}),
        isFalse,
      );
    });
  });
}
