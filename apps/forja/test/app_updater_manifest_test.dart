import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/services/update/app_updater_manifest.dart';

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

  group('AppUpdaterManifest.resolveForArch', () {
    final splitMacos = {
      'published_at': '2026-08-12T00:00:00Z',
      'platforms': {
        'macos': {
          'version': '1.3.267',
          'published_at': '2026-08-12T00:00:00Z',
          'assets': [
            'Forja-1.3.267-macos-arm64.dmg',
            'Forja-1.3.247-macos-x86_64.dmg',
          ],
          'arches': {
            'arm64': {
              'version': '1.3.267',
              'filename': 'Forja-1.3.267-macos-arm64.dmg',
              'published_at': '2026-08-12T00:00:00Z',
            },
            'x86_64': {
              'version': '1.3.247',
              'filename': 'Forja-1.3.247-macos-x86_64.dmg',
              'published_at': '2026-08-10T00:00:00Z',
            },
          },
        },
      },
    };

    test('macos x86_64 uses arch version not platform max', () {
      final target = AppUpdaterManifest.resolveForArch(
        manifest: splitMacos,
        platformKey: 'macos',
        arch: 'x86_64',
      );
      expect(target, isNotNull);
      expect(target!.version, '1.3.247');
      expect(target.filename, 'Forja-1.3.247-macos-x86_64.dmg');
    });

    test('macos arm64 uses newer arch entry', () {
      final target = AppUpdaterManifest.resolveForArch(
        manifest: splitMacos,
        platformKey: 'macos',
        arch: 'arm64',
      );
      expect(target?.version, '1.3.267');
      expect(target?.filename, 'Forja-1.3.267-macos-arm64.dmg');
    });

    test('android_tv armeabi-v7a split does not inherit arm64 version', () {
      final target = AppUpdaterManifest.resolveForArch(
        manifest: {
          'platforms': {
            'android_tv': {
              'version': '1.3.20',
              'assets': [
                'Forja-1.3.20-android-tv-arm64.apk',
                'Forja-1.3.10-android-tv-armeabi-v7a.apk',
              ],
              'arches': {
                'arm64': {
                  'version': '1.3.20',
                  'filename': 'Forja-1.3.20-android-tv-arm64.apk',
                },
                'armeabi-v7a': {
                  'version': '1.3.10',
                  'filename': 'Forja-1.3.10-android-tv-armeabi-v7a.apk',
                },
              },
            },
          },
        },
        platformKey: 'android_tv',
        arch: 'armeabi-v7a',
      );
      expect(target?.version, '1.3.10');
      expect(
        target?.filename,
        'Forja-1.3.10-android-tv-armeabi-v7a.apk',
      );
    });

    test('missing arch returns null — no cross-arch fallback', () {
      final target = AppUpdaterManifest.resolveForArch(
        manifest: {
          'platforms': {
            'macos': {
              'version': '1.3.267',
              'assets': ['Forja-1.3.267-macos-arm64.dmg'],
              'arches': {
                'arm64': {
                  'version': '1.3.267',
                  'filename': 'Forja-1.3.267-macos-arm64.dmg',
                },
              },
            },
          },
        },
        platformKey: 'macos',
        arch: 'x86_64',
      );
      expect(target, isNull);
    });

    test('windows default arch from arches map', () {
      final target = AppUpdaterManifest.resolveForArch(
        manifest: {
          'platforms': {
            'windows': {
              'version': '1.3.247',
              'assets': ['Forja-1.3.247-windows-setup.exe'],
              'arches': {
                'default': {
                  'version': '1.3.247',
                  'filename': 'Forja-1.3.247-windows-setup.exe',
                },
              },
            },
          },
        },
        platformKey: 'windows',
        arch: 'default',
      );
      expect(target?.version, '1.3.247');
    });

    test('falls back to assets list when arches missing', () {
      final target = AppUpdaterManifest.resolveForArch(
        manifest: {
          'platforms': {
            'macos': {
              'version': '1.3.267',
              'assets': [
                'Forja-1.3.267-macos-arm64.dmg',
                'Forja-1.3.247-macos-x86_64.dmg',
              ],
            },
          },
        },
        platformKey: 'macos',
        arch: 'x86_64',
      );
      expect(target?.version, '1.3.247');
      expect(target?.filename, 'Forja-1.3.247-macos-x86_64.dmg');
    });
  });

  group('AppUpdaterManifest.platformKeys', () {
    List<String> android({
      required bool mobileBuild,
      required bool tvHardware,
      bool touchscreen = true,
    }) => AppUpdaterManifest.platformKeys(
      isWindows: false,
      isMacOS: false,
      isLinux: false,
      isAndroid: true,
      androidMobileBuild: mobileBuild,
      androidTvHardware: tvHardware,
      androidTouchscreen: touchscreen,
    );

    test('mobile build → android_mobile only', () {
      expect(android(mobileBuild: true, tvHardware: false), ['android_mobile']);
      expect(android(mobileBuild: true, tvHardware: true), ['android_mobile']);
    });

    test('tv build on TV hardware → android_tv', () {
      expect(android(mobileBuild: false, tvHardware: true), ['android_tv']);
    });

    test('tv build on a phone → android_mobile, then android_tv', () {
      expect(
        android(mobileBuild: false, tvHardware: false),
        ['android_mobile', 'android_tv'],
      );
    });

    test('tv build on a TV box without leanback or touch → android_tv', () {
      expect(
        android(mobileBuild: false, tvHardware: false, touchscreen: false),
        ['android_tv'],
      );
    });

    test('desktop keys unchanged', () {
      expect(
        AppUpdaterManifest.platformKey(
          isWindows: false,
          isMacOS: true,
          isLinux: false,
          isAndroid: false,
        ),
        'macos',
      );
      expect(
        AppUpdaterManifest.platformKeys(
          isWindows: false,
          isMacOS: false,
          isLinux: false,
          isAndroid: false,
        ),
        isEmpty,
      );
    });
  });

  group('AppUpdaterManifest.resolveForArchKeys', () {
    const mobileApk = 'Forja-1.5.2-android-mobile-arm64.apk';
    const tvApk = 'Forja-1.5.2-android-tv-arm64.apk';

    Map<String, dynamic> manifest({required bool withMobile}) => {
      'platforms': {
        'android_tv': {
          'version': '1.5.2',
          'assets': [tvApk],
          'arches': {
            'arm64': {'version': '1.5.2', 'filename': tvApk},
          },
        },
        if (withMobile)
          'android_mobile': {
            'version': '1.5.2',
            'assets': [mobileApk],
            'arches': {
              'arm64': {'version': '1.5.2', 'filename': mobileApk},
            },
          },
      },
    };

    test('tv build on a phone migrates to the mobile installer', () {
      final target = AppUpdaterManifest.resolveForArchKeys(
        manifest: manifest(withMobile: true),
        platformKeys: const ['android_mobile', 'android_tv'],
        arch: 'arm64',
      );
      expect(target?.filename, mobileApk);
    });

    test('falls back to android_tv while no mobile build is published', () {
      final target = AppUpdaterManifest.resolveForArchKeys(
        manifest: manifest(withMobile: false),
        platformKeys: const ['android_mobile', 'android_tv'],
        arch: 'arm64',
      );
      expect(target?.filename, tvApk);
    });

    test('mobile build never falls back to the TV installer', () {
      final target = AppUpdaterManifest.resolveForArchKeys(
        manifest: manifest(withMobile: false),
        platformKeys: const ['android_mobile'],
        arch: 'arm64',
      );
      expect(target, isNull);
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
