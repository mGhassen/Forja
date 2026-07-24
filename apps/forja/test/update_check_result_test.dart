import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/services/app_updater_service.dart';

void main() {
  group('UpdateCheckResult', () {
    test('failed is not up to date', () {
      final result = UpdateCheckResult.failed('network');
      expect(result.isFailed, isTrue);
      expect(result.isUpToDate, isFalse);
      expect(result.isAvailable, isFalse);
      expect(result.failureMessage, 'network');
    });

    test('upToDate has no failure', () {
      final result = UpdateCheckResult.upToDate();
      expect(result.isUpToDate, isTrue);
      expect(result.isFailed, isFalse);
      expect(result.info, isNull);
    });

    test('available carries UpdateInfo', () {
      final info = UpdateInfo(
        currentVersion: '1.2.406',
        latestVersion: '1.2.434',
        downloadUrl: 'https://cdn.example/a.dmg',
        changelogs: const [],
        fullChangelogUrl: 'https://example/changelog',
        publishedAt: DateTime.utc(2026, 7, 24),
        isMacOS: true,
      );
      final result = UpdateCheckResult.available(info);
      expect(result.isAvailable, isTrue);
      expect(result.info?.latestVersion, '1.2.434');
      expect(result.isUpToDate, isFalse);
    });
  });
}
