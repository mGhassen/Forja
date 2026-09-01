import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/plugin_contract.dart';

/// Repo-root `plugins/` — test cwd is `apps/forja`.
File _repoFile(String rel) => File('../../$rel');

Map<String, dynamic> _readJson(String rel) {
  final file = _repoFile(rel);
  expect(file.existsSync(), isTrue, reason: 'missing ${file.path}');
  return Map<String, dynamic>.from(jsonDecode(file.readAsStringSync()) as Map);
}

dynamic _readJsonAny(String rel) {
  final file = _repoFile(rel);
  expect(file.existsSync(), isTrue, reason: 'missing ${file.path}');
  return jsonDecode(file.readAsStringSync());
}

void main() {
  group('plugin SDK contract index', () {
    test('contract.json lists schema files that exist', () {
      final contract = _readJson('plugins/sdk/contract.json');
      expect(contract['schema'], 1);
      expect(contract['kitVersion'], 1);
      expect(contract['protocolVersion'], 1);
      final schemas = contract['schemas'] as Map;
      for (final entry in schemas.entries) {
        final path = 'plugins/sdk/${entry.value}';
        expect(_repoFile(path).existsSync(), isTrue, reason: path);
      }
      final kits = contract['kits'] as Map;
      for (final entry in kits.entries) {
        final path = 'plugins/sdk/${entry.value}';
        expect(_repoFile(path).existsSync(), isTrue, reason: path);
      }
    });
  });

  group('official pack manifests', () {
    final manifests = [
      'plugins/providers/manifest.json',
      'plugins/live/manifest.json',
      'plugins/torrent/manifest.json',
      'plugins/hubs/home/manifest.json',
      'plugins/hubs/anime/manifest.json',
      'plugins/hubs/asian_drama/manifest.json',
      'plugins/hubs/my_list/manifest.json',
      'plugins/iptv/vod/manifest.json',
    ];

    for (final path in manifests) {
      test('validates $path', () {
        PluginContract.validateManifest(_readJson(path));
      });
    }
  });

  group('catalog fixtures', () {
    final fixtures = [
      'plugins/hubs/fixtures/anilist_layout.json',
      'plugins/hubs/fixtures/anilist_rail.json',
      'plugins/hubs/fixtures/kisskh_rail.json',
      'plugins/hubs/fixtures/tmdb_auth_required.json',
      'plugins/hubs/fixtures/unsupported_kit.json',
    ];

    for (final path in fixtures) {
      test('validates envelope $path', () {
        PluginContract.validateCatalogEnvelope(_readJsonAny(path));
      });
    }
  });

  group('torrent row contract', () {
    test('accepts canonical row shape', () {
      PluginContract.validateTorrentRow({
        'name': 'Example 1080p',
        'magnet': 'magnet:?xt=urn:btih:abc123&dn=Example',
        'seeders': '42',
        'size': '1.2 GB',
        'source': 'Knaben',
      });
    });

    test('rejects bad magnet', () {
      expect(
        () => PluginContract.validateTorrentRow({
          'name': 'x',
          'magnet': 'http://bad',
          'seeders': '0',
          'size': '1 GB',
          'source': 'X',
        }),
        throwsFormatException,
      );
    });
  });

  group('VOD stream contract', () {
    test('accepts url alias fields', () {
      PluginContract.validateVodStreams([
        {'url': 'https://cdn.example/a.m3u8', 'title': '1080p'},
        {'file': 'https://cdn.example/b.mp4'},
      ]);
    });
  });
}
