import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/services/app_updater_manifest.dart';

void main() {
  group('AppUpdaterManifest.resolve', () {
    test('uses platforms map for this platform version', () {
      final target = AppUpdaterManifest.resolve(
        manifest: {
          'version': '1.2.406',
          'assets': [
            'Forja-1.2.406-macos-arm64.dmg',
            'Forja-1.2.400-windows-setup.exe',
          ],
          'platforms': {
            'macos': {
              'version': '1.2.406',
              'assets': ['Forja-1.2.406-macos-arm64.dmg'],
            },
            'windows': {
              'version': '1.2.400',
              'assets': ['Forja-1.2.400-windows-setup.exe'],
            },
          },
        },
        platformKey: 'windows',
      );
      expect(target, isNotNull);
      expect(target!.version, '1.2.400');
      expect(target.assets, ['Forja-1.2.400-windows-setup.exe']);
    });

    test('falls back to legacy flat version + assets', () {
      final target = AppUpdaterManifest.resolve(
        manifest: {
          'version': '1.2.400',
          'assets': ['Forja-1.2.400-windows-setup.exe'],
        },
        platformKey: 'windows',
      );
      expect(target?.version, '1.2.400');
    });

    test('isUpdateAvailable compares against platform version not max', () {
      final target = AppUpdaterManifest.resolve(
        manifest: {
          'version': '1.2.406',
          'platforms': {
            'windows': {
              'version': '1.2.400',
              'assets': ['Forja-1.2.400-windows-setup.exe'],
            },
          },
        },
        platformKey: 'windows',
      )!;
      expect(
        AppUpdaterManifest.isUpdateAvailable(
          currentVersion: '1.2.400',
          target: target,
        ),
        isFalse,
      );
      expect(
        AppUpdaterManifest.isUpdateAvailable(
          currentVersion: '1.2.399',
          target: target,
        ),
        isTrue,
      );
    });
  });

  group('AppUpdaterManifest.versionFromFilename', () {
    test('reads Forja-{semver}-… names', () {
      expect(
        AppUpdaterManifest.versionFromFilename(
          'Forja-1.3.192-macos-arm64.dmg',
        ),
        '1.3.192',
      );
      expect(
        AppUpdaterManifest.versionFromFilename(
          'Forja-1.2.400-windows-setup.exe',
        ),
        '1.2.400',
      );
    });

    test('returns null when no semver', () {
      expect(AppUpdaterManifest.versionFromFilename('readme.txt'), isNull);
    });
  });
}
