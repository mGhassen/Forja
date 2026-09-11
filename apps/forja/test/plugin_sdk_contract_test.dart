import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/packs/forja_packs_root.dart';
import 'package:forja/shared/engine/packs/registry/plugin_contract.dart';

/// Sibling [forja-sdk] or `FORJA_SDK_ROOT` — schemas / kits / fixtures.
String? _sdkRoot() {
  final env = Platform.environment['FORJA_SDK_ROOT']?.trim() ?? '';
  if (env.isNotEmpty) {
    final d = Directory(env);
    if (d.existsSync()) return d.absolute.path.replaceAll('\\', '/');
  }
  var dir = Directory.current;
  for (var i = 0; i < 8; i++) {
    final sibling = Directory('${dir.path}/forja-sdk');
    if (sibling.existsSync() &&
        File('${sibling.path}/contract.json').existsSync()) {
      return sibling.absolute.path.replaceAll('\\', '/');
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return null;
}

/// Pack inventory — [forja-packs] via `FORJA_PACKS_ROOT` only.
String? _packsRoot() => ForjaPacksRoot.resolve(requireDebug: false);

File? _sdkFile(String rel) {
  final root = _sdkRoot();
  if (root == null) return null;
  return File('$root/$rel');
}

File? _packsFile(String rel) {
  final root = _packsRoot();
  if (root == null) return null;
  return File('$root/$rel');
}

Map<String, dynamic> _readSdkJson(String rel) {
  final file = _sdkFile(rel);
  expect(file, isNotNull, reason: 'forja-sdk not found for $rel');
  expect(file!.existsSync(), isTrue, reason: 'missing ${file.path}');
  return Map<String, dynamic>.from(jsonDecode(file.readAsStringSync()) as Map);
}

dynamic _readSdkJsonAny(String rel) {
  final file = _sdkFile(rel);
  expect(file, isNotNull, reason: 'forja-sdk not found for $rel');
  expect(file!.existsSync(), isTrue, reason: 'missing ${file.path}');
  return jsonDecode(file.readAsStringSync());
}

Map<String, dynamic> _readPacksJson(String rel) {
  final file = _packsFile(rel);
  expect(file, isNotNull, reason: 'forja-packs not found for $rel');
  expect(file!.existsSync(), isTrue, reason: 'missing ${file.path}');
  return Map<String, dynamic>.from(jsonDecode(file.readAsStringSync()) as Map);
}

void main() {
  final sdkReady = _sdkRoot() != null;
  final packsReady = _packsRoot() != null;

  group('plugin SDK contract index', () {
    test('contract.json lists schema files that exist', () {
      if (!sdkReady) {
        // Host CI without sibling forja-sdk — skip SDK oracle.
        return;
      }
      final contract = _readSdkJson('contract.json');
      expect(contract['schema'], 1);
      expect(contract['kitVersion'], 1);
      expect(contract['protocolVersion'], 1);
      final schemas = contract['schemas'] as Map;
      for (final entry in schemas.entries) {
        final path = '${entry.value}';
        expect(_sdkFile(path)!.existsSync(), isTrue, reason: path);
      }
      final kits = contract['kits'] as Map;
      for (final entry in kits.entries) {
        final path = '${entry.value}';
        expect(_sdkFile(path)!.existsSync(), isTrue, reason: path);
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
        final file = _packsFile(path);
        if (file == null || !file.existsSync()) return;
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
      'fixtures/anilist_layout.json',
      'fixtures/anilist_rail.json',
      'fixtures/kisskh_rail.json',
      'fixtures/tmdb_auth_required.json',
      'fixtures/unsupported_kit.json',
    ];

    for (final path in fixtures) {
      test('validates envelope $path', () {
        if (!sdkReady) return;
        PluginContract.validateMetaEnvelope(_readSdkJsonAny(path));
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
