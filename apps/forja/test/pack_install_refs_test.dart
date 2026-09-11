import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/packs/install/pack_install_refs.dart';

void main() {
  group('parsePackInstallRefs', () {
    test('splits newlines and appends manifest.json for folders', () {
      expect(
        parsePackInstallRefs('''
/Users/me/forja-packs/hubs/home
/Users/me/forja-packs/providers
'''),
        [
          '/Users/me/forja-packs/hubs/home/manifest.json',
          '/Users/me/forja-packs/providers/manifest.json',
        ],
      );
    });

    test('keeps full manifest paths and http urls', () {
      expect(
        parsePackInstallRefs(
          'https://cdn.example/p/manifest.json\n'
          '/tmp/packs/anime/manifest.json',
        ),
        [
          'https://cdn.example/p/manifest.json',
          '/tmp/packs/anime/manifest.json',
        ],
      );
    });

    test('splits comma lists and dedupes', () {
      expect(
        parsePackInstallRefs(
          '/a/hubs/home, /a/hubs/home; /a/providers',
        ),
        [
          '/a/hubs/home/manifest.json',
          '/a/providers/manifest.json',
        ],
      );
    });

    test('recovers space-flattened absolute paths', () {
      expect(
        parsePackInstallRefs(
          '/Users/me/forja-packs/hubs/home /Users/me/forja-packs/hubs/anime',
        ),
        [
          '/Users/me/forja-packs/hubs/home/manifest.json',
          '/Users/me/forja-packs/hubs/anime/manifest.json',
        ],
      );
    });

    test('single ref stays one entry', () {
      expect(
        parsePackInstallRefs('https://example.com/manifest.json'),
        ['https://example.com/manifest.json'],
      );
    });
  });

  group('packInstallRefDisplayName', () {
    test('uses pack folder name', () {
      expect(
        packInstallRefDisplayName('/Users/me/hubs/home/manifest.json'),
        'home',
      );
      expect(
        packInstallRefDisplayName('https://cdn.example/providers/manifest.json'),
        'providers',
      );
    });
  });
}
