import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/packs/forja_packs_root.dart';
import 'package:forja/shared/engine/packs/registry/plugin_contract.dart';

/// Pack/SDK files live in sibling [forja-packs] (or legacy `plugins/` / `sdk/`).
String? _packsRoot() => ForjaPacksRoot.resolve(requireDebug: false);

File? _packsFile(String rel) {
  final root = _packsRoot();
  if (root == null) return null;
  return File('$root/$rel');
}

Map<String, dynamic> _readPacksJson(String rel) {
  final file = _packsFile(rel);
  expect(file, isNotNull, reason: 'forja-packs not found for $rel');
  expect(file!.existsSync(), isTrue, reason: 'missing ${file.path}');
  return Map<String, dynamic>.from(jsonDecode(file.readAsStringSync()) as Map);
}

dynamic _readPacksJsonAny(String rel) {
  final file = _packsFile(rel);
  expect(file, isNotNull, reason: 'forja-packs not found for $rel');
  expect(file!.existsSync(), isTrue, reason: 'missing ${file.path}');
  return jsonDecode(file.readAsStringSync());
}

void main() {
  final packsReady = _packsRoot() != null;

  group('plugin SDK contract index', () {
    test('contract.json lists schema files that exist', () {
      if (!packsReady) {
        // Host CI without sibling forja-packs — skip pack-tree oracle.
        return;
      }
      final contract = _readPacksJson('sdk/contract.json');
      expect(contract['schema'], 1);
      expect(contract['kitVersion'], 1);
      expect(contract['protocolVersion'], 1);
      final schemas = contract['schemas'] as Map;
      for (final entry in schemas.entries) {
        final path = 'sdk/${entry.value}';
        expect(_packsFile(path)!.existsSync(), isTrue, reason: path);
      }
      final kits = contract['kits'] as Map;
      for (final entry in kits.entries) {
        final path = 'sdk/${entry.value}';
        expect(_packsFile(path)!.existsSync(), isTrue, reason: path);
      }
    });
  });

  group('official pack manifests', () {
    final manifests = [
      'providers/manifest.json',
      'catalog/manifest.json',
      'live/manifest.json',
      'torrent/manifest.json',
      'hubs/home/manifest.json',
      'hubs/anime/manifest.json',
      'hubs/asian_drama/manifest.json',
      'hubs/my_list/manifest.json',
      'hubs/live_sports/manifest.json',
      'hubs/arabic/manifest.json',
      'hubs/aflem/manifest.json',
      'hubs/cartoon/manifest.json',
      'hubs/kids/manifest.json',
      'iptv/vod/manifest.json',
    ];

    for (final path in manifests) {
      test('validates $path', () {
        if (!packsReady) return;
        PluginContract.validateManifest(_readPacksJson(path));
      });
    }

    test('rejects pack or plugin enabled field', () {
      expect(
        () => PluginContract.validateManifest({
          'schema': 1,
          'id': 'pack',
          'name': 'Pack',
          'version': '1.0.0',
          'enabled': true,
          'plugins': [
            {'id': 'p', 'name': 'P', 'entry': 'p.js'},
          ],
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('must not declare enabled'),
          ),
        ),
      );
      expect(
        () => PluginContract.validateManifest({
          'schema': 1,
          'id': 'pack',
          'name': 'Pack',
          'version': '1.0.0',
          'plugins': [
            {
              'id': 'p',
              'name': 'P',
              'entry': 'p.js',
              'enabled': true,
            },
          ],
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('must not declare enabled'),
          ),
        ),
      );
    });
  });

  group('catalog fixtures', () {
    final fixtures = [
      'sdk/fixtures/anilist_layout.json',
      'sdk/fixtures/anilist_rail.json',
      'sdk/fixtures/kisskh_rail.json',
      'sdk/fixtures/tmdb_auth_required.json',
      'sdk/fixtures/unsupported_kit.json',
    ];

    for (final path in fixtures) {
      test('validates envelope $path', () {
        if (!packsReady) return;
        PluginContract.validateMetaEnvelope(_readPacksJsonAny(path));
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
