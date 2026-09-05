import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/models.dart';
import 'package:forja/shared/engine/plugin_registry.dart';
import 'package:forja/shared/engine/plugin_script_disk_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('pack manifest bundle list', () {
    late PluginRegistry registry;
    late Directory diskRoot;
    final got = <String>[];

    setUp(() async {
      registry = PluginRegistry.instance;
      registry.debugHttpClient = null;
      got.clear();
      diskRoot = await Directory.systemTemp.createTemp('pack_bundle_');
      PluginScriptDiskStore.debugRoot = diskRoot;
      SharedPreferences.setMockInitialValues({
        'engine_js_packs_v2_migrated': true,
        'engine_js_scripts_disk_v3_migrated': true,
      });
    });

    tearDown(() async {
      registry.debugHttpClient = null;
      PluginScriptDiskStore.resetForTest();
      if (await diskRoot.exists()) {
        await diskRoot.delete(recursive: true);
      }
    });

    test('parses bundle as file path list', () {
      final pack = EnginePack.fromJson(
        {
          'schema': 1,
          'id': 'x',
          'name': 'X',
          'version': '1.0.0',
          'bundle': ['a.js', 'hops/b.js', 'a.js'],
          'plugins': [
            {'id': 'p', 'name': 'P', 'entry': 'a.js', 'kind': 'http'},
          ],
        },
        sourceUrl: 'https://x/manifest.json',
      );
      expect(pack.bundle, ['a.js', 'hops/b.js']);
    });

    test('legacy string bundle is ignored', () {
      final pack = EnginePack.fromJson(
        {
          'schema': 1,
          'id': 'x',
          'name': 'X',
          'version': '1.0.0',
          'bundle': 'pack.zip',
          'plugins': [
            {'id': 'p', 'name': 'P', 'entry': 'a.js', 'kind': 'http'},
          ],
        },
        sourceUrl: 'https://x/manifest.json',
      );
      expect(pack.bundle, isEmpty);
    });

    test('install downloads every path listed in bundle', () async {
      const url = 'https://cdn.example/pack/manifest.json';
      registry.debugHttpClient = MockClient((req) async {
        final u = req.url.toString();
        got.add(u);
        if (u == url) {
          return http.Response(
            jsonEncode({
              'schema': 1,
              'id': 'listed',
              'name': 'Listed',
              'version': '1.0.0',
              'bundle': ['alpha.js', 'hops/gamma.js'],
              'plugins': [
                {
                  'id': 'alpha',
                  'name': 'Alpha',
                  'entry': 'alpha.js',
                  'kind': 'http',
                },
                {
                  'id': 'gamma',
                  'name': 'Gamma',
                  'entry': 'hops/gamma.js',
                  'kind': 'hop',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (u.endsWith('alpha.js')) {
          return http.Response('function extract(ctx) { return []; }', 200);
        }
        if (u.endsWith('hops/gamma.js') || u.endsWith('gamma.js')) {
          return http.Response('function hop(ctx) { return null; }', 200);
        }
        return http.Response('not found', 404);
      });

      final pack = await registry.install(url);
      expect(pack.plugins, hasLength(2));
      expect(got.where((u) => u.endsWith('.js')).length, 2);
      expect(
        await PluginScriptDiskStore.loadEngineScript(
          sourceUrl: url,
          pluginId: 'gamma',
        ),
        'function hop(ctx) { return null; }',
      );
    });

    test('missing bundled file fails transactionally', () async {
      const url = 'https://cdn.example/miss/manifest.json';
      registry.debugHttpClient = MockClient((req) async {
        final u = req.url.toString();
        if (u == url) {
          return http.Response(
            jsonEncode({
              'schema': 1,
              'id': 'miss',
              'name': 'Miss',
              'version': '1.0.0',
              'bundle': ['only.js', 'gone.js'],
              'plugins': [
                {
                  'id': 'only',
                  'name': 'Only',
                  'entry': 'only.js',
                  'kind': 'http',
                },
                {
                  'id': 'gone',
                  'name': 'Gone',
                  'entry': 'gone.js',
                  'kind': 'http',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (u.endsWith('only.js')) {
          return http.Response('function extract(ctx) { return []; }', 200);
        }
        return http.Response('not found', 404);
      });

      await expectLater(
        registry.install(url),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('missing scripts'),
          ),
        ),
      );
      expect(
        await PluginScriptDiskStore.hasEngineScript(
          sourceUrl: url,
          pluginId: 'only',
        ),
        isFalse,
      );
    });
  });
}
