import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/packs/install/forja_plugin_deeplink.dart';
import 'package:forja/shared/engine/packs/registry/pack_source_url_policy.dart';
import 'package:forja/shared/engine/packs/registry/plugin_registry.dart';
import 'package:forja/shared/engine/packs/registry/plugin_script_disk_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _manifestJson() => jsonEncode({
  'schema': 1,
  'id': 'synthetic',
  'name': 'Synthetic Pack',
  'version': '1.0.0',
  'plugins': [
    {'id': 'p1', 'name': 'P1', 'entry': 'p1.js', 'kind': 'http'},
  ],
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PackSourceUrlPolicy', () {
    test('https allowed; http, ftp, data, javascript refused', () {
      expect(
        PackSourceUrlPolicy.refuseReason(
          'https://cdn.example/manifest.json',
          allowLocal: false,
        ),
        isNull,
      );
      for (final u in [
        'http://cdn.example/manifest.json',
        'ftp://cdn.example/manifest.json',
        'data:application/json,{}',
        'javascript:alert(1)',
        'cdn.example/manifest.json',
        '',
      ]) {
        expect(
          PackSourceUrlPolicy.refuseReason(u, allowLocal: true),
          PackSourceUrlPolicy.refusedMessage,
          reason: u,
        );
      }
    });

    test('local checkout paths depend on allowLocal', () {
      for (final u in ['/tmp/packs/manifest.json', 'file:///tmp/m.json']) {
        expect(PackSourceUrlPolicy.refuseReason(u, allowLocal: true), isNull);
        expect(
          PackSourceUrlPolicy.refuseReason(u, allowLocal: false),
          PackSourceUrlPolicy.localRefusedMessage,
        );
      }
    });

    test('does not silently upgrade http to https', () {
      expect(
        () => PackSourceUrlPolicy.assertAllowed(
          'http://cdn.example/manifest.json',
          allowLocal: true,
        ),
        throwsA(
          isA<PackSourceRefusedException>().having(
            (e) => e.toString(),
            'message',
            contains('https://'),
          ),
        ),
      );
    });
  });

  group('PluginRegistry https floor', () {
    late PluginRegistry registry;
    late Directory diskRoot;

    setUp(() async {
      registry = PluginRegistry.instance;
      diskRoot = await Directory.systemTemp.createTemp('https_floor_');
      PluginScriptDiskStore.resetForTest();
      PluginScriptDiskStore.debugRoot = diskRoot;
      SharedPreferences.setMockInitialValues({
        'engine_js_packs_v2_migrated': true,
        'engine_js_scripts_disk_v3_migrated': true,
      });
    });

    tearDown(() async {
      registry.debugHttpClient = null;
      PluginScriptDiskStore.resetForTest();
      if (await diskRoot.exists()) await diskRoot.delete(recursive: true);
    });

    test('http manifest is refused before any request', () async {
      var requests = 0;
      registry.debugHttpClient = MockClient((req) async {
        requests++;
        return http.Response(_manifestJson(), 200);
      });
      await expectLater(
        registry.install('http://cdn.example/pack/manifest.json'),
        throwsA(
          isA<PackSourceRefusedException>().having(
            (e) => e.message,
            'message',
            PackSourceUrlPolicy.refusedMessage,
          ),
        ),
      );
      expect(requests, 0);
      final packs = await registry.listPacksRaw();
      expect(packs.where((p) => p.sourceUrl.startsWith('http://')), isEmpty);
    });

    test('https manifest with https scripts installs', () async {
      const url = 'https://cdn.example/pack/manifest.json';
      registry.debugHttpClient = MockClient((req) async {
        expect(req.url.scheme, 'https');
        if (req.url.toString() == url) {
          return http.Response(_manifestJson(), 200);
        }
        if (req.url.path.endsWith('p1.js')) {
          return http.Response('function extract(ctx) { return []; }', 200);
        }
        return http.Response('nf', 404);
      });
      final pack = await registry.install(url);
      expect(pack.plugins.single.id, 'p1');
      await registry.removePack(url);
    });

    test(
      'http script url inside an https manifest fails the install',
      () async {
        const url = 'https://cdn.example/mixed/manifest.json';
        registry.debugHttpClient = MockClient((req) async {
          if (req.url.toString() == url) {
            return http.Response(
              jsonEncode({
                'schema': 1,
                'id': 'mixed',
                'name': 'Mixed',
                'version': '1.0.0',
                'plugins': [
                  {
                    'id': 'p1',
                    'name': 'P1',
                    'entry': 'http://cdn.example/p1.js',
                    'kind': 'http',
                  },
                ],
              }),
              200,
            );
          }
          return http.Response('nf', 404);
        });
        await expectLater(
          registry.install(url),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('https://'),
            ),
          ),
        );
      },
    );

    test('local checkout manifest still installs', () async {
      final dir = await Directory.systemTemp.createTemp('local_pack_');
      try {
        final manifest = File('${dir.path}/manifest.json');
        await manifest.writeAsString(_manifestJson());
        await File(
          '${dir.path}/p1.js',
        ).writeAsString('function extract(ctx) { return []; }');
        registry.debugHttpClient = MockClient(
          (req) async => fail('local checkout must not hit the network'),
        );
        final pack = await registry.install(manifest.path);
        expect(pack.plugins.single.id, 'p1');
        await registry.removePack(manifest.path);
      } finally {
        if (await dir.exists()) await dir.delete(recursive: true);
      }
    });
  });

  group('ForjaPluginDeepLink https floor', () {
    test('http manifest param is dropped', () {
      final uri = Uri.parse(
        'forja://install?manifest=http%3A%2F%2Fevil.example%2Fmanifest.json',
      );
      expect(ForjaPluginDeepLink.parseManifestUrl(uri), isNull);
      expect(
        ForjaPluginDeepLink.refuseReason('http://evil.example/manifest.json'),
        PackSourceUrlPolicy.refusedMessage,
      );
    });

    test('https manifest param passes', () {
      final uri = Uri.parse(
        'forja://install?manifest=https%3A%2F%2Fexample.com%2Fmanifest.json',
      );
      expect(
        ForjaPluginDeepLink.parseManifestUrl(uri),
        'https://example.com/manifest.json',
      );
    });

    test('batch keeps https rows, reports http rows', () {
      final packs = Uri.encodeComponent(
        jsonEncode([
          {'m': 'https://example.com/a/manifest.json', 'n': 'Pack A'},
          {'m': 'http://example.com/b/manifest.json', 'n': 'Pack B'},
        ]),
      );
      final refused = <String>[];
      final batch = ForjaPluginDeepLink.parseBatchCandidates(
        Uri.parse('forja://install?batch=1&packs=$packs'),
        onRefused: (url, name, reason) => refused.add('$name:$url:$reason'),
      );
      expect(batch, hasLength(1));
      expect(batch!.single.manifestUrl, 'https://example.com/a/manifest.json');
      expect(refused, hasLength(1));
      expect(refused.single, startsWith('Pack B:http://example.com/b/'));
      expect(refused.single, contains('https://'));
    });
  });
}
