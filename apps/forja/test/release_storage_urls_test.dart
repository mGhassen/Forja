import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/services/release_storage_urls.dart';

void main() {
  group('ReleaseStorageUrls.isDirectInstallerUrl', () {
    test('accepts CDN latest and versioned installer paths', () {
      expect(
        ReleaseStorageUrls.isDirectInstallerUrl(
          'https://cdn.forjahq.xyz/latest/Forja-1.2.308-macos-arm64.dmg',
        ),
        isTrue,
      );
      expect(
        ReleaseStorageUrls.isDirectInstallerUrl(
          'https://cdn.forjahq.xyz/v1.2.308/Forja-1.2.308-windows-setup.exe',
        ),
        isTrue,
      );
    });

    test('accepts GitHub release asset URLs', () {
      expect(
        ReleaseStorageUrls.isDirectInstallerUrl(
          'https://github.com/mGhassen/Forja/releases/download/v1.2.308/Forja-1.2.308-linux-x86_64.AppImage',
        ),
        isTrue,
      );
    });

    test('rejects GitHub HTML release pages', () {
      expect(
        ReleaseStorageUrls.isDirectInstallerUrl(
          'https://github.com/mGhassen/Forja/releases/tag/v1.2.308',
        ),
        isFalse,
      );
      expect(
        ReleaseStorageUrls.isDirectInstallerUrl(
          'https://github.com/mGhassen/Forja/releases',
        ),
        isFalse,
      );
    });
  });
}
