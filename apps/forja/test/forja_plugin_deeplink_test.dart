import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/forja_plugin_deeplink.dart';

void main() {
  group('ForjaPluginDeepLink', () {
    test('parses forja://install?manifest=', () {
      final uri = Uri.parse(
        'forja://install?manifest=https%3A%2F%2Fexample.com%2Fmanifest.json',
      );
      expect(ForjaPluginDeepLink.parseManifestUrl(uri), isNotNull);
      expect(
        ForjaPluginDeepLink.parseManifestUrl(uri),
        'https://example.com/manifest.json',
      );
    });

    test('parses legacy url query param', () {
      final uri = Uri.parse(
        'forja://install?url=https%3A%2F%2Fexample.com%2Fmanifest.json',
      );
      expect(
        ForjaPluginDeepLink.parseManifestUrl(uri),
        'https://example.com/manifest.json',
      );
    });

    test('rejects non-install links', () {
      expect(
        ForjaPluginDeepLink.parseManifestUrl(
          Uri.parse('forja://catalog/anilist/details?id=1'),
        ),
        isNull,
      );
    });
  });
}
