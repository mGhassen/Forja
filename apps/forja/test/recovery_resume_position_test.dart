import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/screens/utils.dart';

void main() {
  const dur = Duration(minutes: 23, seconds: 40);

  group('isHealthyPlayheadSample', () {
    test('accepts the playhead advancing by a normal step', () {
      expect(
        isHealthyPlayheadSample(
          previous: const Duration(minutes: 10),
          reported: const Duration(minutes: 10, seconds: 1),
          duration: dur,
        ),
        isTrue,
      );
    });

    test('rejects a dead-CDN jump from mid-episode to duration', () {
      expect(
        isHealthyPlayheadSample(
          previous: const Duration(minutes: 10),
          reported: dur,
          duration: dur,
        ),
        isFalse,
      );
    });

    test('rejects repeated reports sitting at EOF', () {
      expect(
        isHealthyPlayheadSample(
          previous: dur,
          reported: dur,
          duration: dur,
        ),
        isFalse,
      );
    });

    test('rejects zero (keep-open reset / fresh open)', () {
      expect(
        isHealthyPlayheadSample(
          previous: Duration.zero,
          reported: Duration.zero,
          duration: dur,
        ),
        isFalse,
      );
    });

    test('accepts reports near a user seek target', () {
      // _seekTo sets the shown position to the target before mpv reports.
      expect(
        isHealthyPlayheadSample(
          previous: const Duration(minutes: 18),
          reported: const Duration(minutes: 18, milliseconds: 400),
          duration: dur,
        ),
        isTrue,
      );
    });

    test('ignores EOF guard while duration is unknown', () {
      expect(
        isHealthyPlayheadSample(
          previous: const Duration(seconds: 30),
          reported: const Duration(seconds: 31),
          duration: Duration.zero,
        ),
        isTrue,
      );
    });
  });

  group('recoveryResumePosition', () {
    test('prefers the last healthy sample over a rewritten seek bar', () {
      expect(
        recoveryResumePosition(
          lastHealthy: const Duration(minutes: 10),
          shown: Duration.zero,
        ),
        const Duration(minutes: 10),
      );
      expect(
        recoveryResumePosition(
          lastHealthy: const Duration(minutes: 10),
          shown: dur,
        ),
        const Duration(minutes: 10),
      );
    });

    test('falls back to the shown position before any sample', () {
      expect(
        recoveryResumePosition(
          lastHealthy: Duration.zero,
          shown: const Duration(minutes: 2),
        ),
        const Duration(minutes: 2),
      );
    });
  });
}
