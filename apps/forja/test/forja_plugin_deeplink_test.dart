import 'dart:convert';

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

    test('parses batch packs and ignores single manifest parser', () {
      final packs = Uri.encodeComponent(
        jsonEncode([
          {'m': 'https://example.com/a/manifest.json', 'n': 'Pack A'},
          {'m': 'https://example.com/b/manifest.json'},
        ]),
      );
      final uri = Uri.parse('forja://install?batch=1&packs=$packs');
      expect(ForjaPluginDeepLink.parseManifestUrl(uri), isNull);
      final batch = ForjaPluginDeepLink.parseBatchCandidates(uri);
      expect(batch, isNotNull);
      expect(batch, hasLength(2));
      expect(batch!.first.manifestUrl, 'https://example.com/a/manifest.json');
      expect(batch.first.displayName, 'Pack A');
      expect(batch[1].manifestUrl, 'https://example.com/b/manifest.json');
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
