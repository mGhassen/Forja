import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/services/app_update_auto_check_policy.dart';

void main() {
  group('AppUpdateAutoCheckPolicy.shouldNetworkCheck', () {
    final now = DateTime.utc(2026, 7, 29, 16);

    test('runs when never checked', () {
      expect(
        AppUpdateAutoCheckPolicy.shouldNetworkCheck(
          now: now,
          lastCheckAt: null,
          autoCheckEnabled: true,
        ),
        isTrue,
      );
    });

    test('skips when disabled', () {
      expect(
        AppUpdateAutoCheckPolicy.shouldNetworkCheck(
          now: now,
          lastCheckAt: null,
          autoCheckEnabled: false,
        ),
        isFalse,
      );
    });

    test('skips inside the interval', () {
      expect(
        AppUpdateAutoCheckPolicy.shouldNetworkCheck(
          now: now,
          lastCheckAt: now.subtract(const Duration(minutes: 30)),
          autoCheckEnabled: true,
        ),
        isFalse,
      );
    });

    test('runs at or after the interval', () {
      expect(
        AppUpdateAutoCheckPolicy.shouldNetworkCheck(
          now: now,
          lastCheckAt: now.subtract(const Duration(hours: 1)),
          autoCheckEnabled: true,
        ),
        isTrue,
      );
      expect(
        AppUpdateAutoCheckPolicy.shouldNetworkCheck(
          now: now,
          lastCheckAt: now.subtract(const Duration(hours: 2)),
          autoCheckEnabled: true,
        ),
        isTrue,
      );
    });
  });

  group('AppUpdateAutoCheckPolicy.shouldPrompt', () {
    test('prompts when nothing dismissed', () {
      expect(
        AppUpdateAutoCheckPolicy.shouldPrompt(
          latestVersion: '1.3.70',
          dismissedVersion: null,
        ),
        isTrue,
      );
    });

    test('skips the dismissed version', () {
      expect(
        AppUpdateAutoCheckPolicy.shouldPrompt(
          latestVersion: '1.3.70',
          dismissedVersion: '1.3.70',
        ),
        isFalse,
      );
    });

    test('prompts again when a newer version ships', () {
      expect(
        AppUpdateAutoCheckPolicy.shouldPrompt(
          latestVersion: '1.3.71',
          dismissedVersion: '1.3.70',
        ),
        isTrue,
      );
    });
  });
}
