import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/engine/models.dart';
import 'package:forja/shared/engine/plugin_contract.dart';
import 'package:forja/shared/engine/plugin_install_validator.dart';
import 'package:forja/shared/engine/plugin_registry.dart';
import 'package:forja/shared/engine/plugin_script_disk_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PluginInstallValidator.debugSkipSmokeLoad = false;
  });

  group('PluginInstallValidator', () {
    test('rejects cross-origin absolute script URL on remote manifest', () async {
      const manifestUrl = 'https://cdn.example/pack/manifest.json';
      final pack = EnginePack.fromJson(
        {
          'schema': 1,
          'id': 'x',
          'name': 'X',
          'version': '1.0.0',
          'plugins': [
            {
              'id': 'p1',
              'name': 'P1',
              'entry': 'https://evil.example/p1.js',
              'kind': 'http',
            },
          ],
        },
        sourceUrl: manifestUrl,
      );
      await expectLater(
        PluginInstallValidator.validateBeforeCommit(
          manifestUrl: manifestUrl,
          manifest: pack.toJson(),
          pack: pack,
          scripts: const {'p1': 'function extract() { return []; }'},
          preludes: const {},
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('manifest origin'),
          ),
        ),
      );
    });

    test('rejects script larger than per-file limit', () async {
      const manifestUrl = 'https://cdn.example/pack/manifest.json';
      final pack = EnginePack.fromJson(
        {
          'schema': 1,
          'id': 'x',
          'name': 'X',
          'version': '1.0.0',
          'plugins': [
            {
              'id': 'p1',
              'name': 'P1',
              'entry': 'p1.js',
              'kind': 'http',
            },
          ],
        },
        sourceUrl: manifestUrl,
      );
      final huge = 'function extract() { return []; }${' ' * (PluginInstallValidator.maxScriptBytes + 1)}';
      await expectLater(
        PluginInstallValidator.validateBeforeCommit(
          manifestUrl: manifestUrl,
          manifest: pack.toJson(),
          pack: pack,
          scripts: {'p1': huge},
          preludes: const {},
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('exceeds'),
          ),
        ),
      );
    });

    test('rejects catalog plugin with unsupported kit at manifest parse', () {
      expect(
        () => PluginContract.validateManifest({
          'schema': 1,
          'id': 'hub',
          'name': 'Hub',
          'version': '1.0.0',
          'plugins': [
            {
              'id': 'future-hub',
              'name': 'Future',
              'entry': 'hub.js',
              'kind': 'catalog',
              'kit': hostKitVersion + 1,
              'protocol': 1,
            },
          ],
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('requires kit'),
          ),
        ),
      );
    });

    test('smoke load rejects syntactically invalid JS', () async {
      const manifestUrl = 'https://cdn.example/pack/manifest.json';
      final pack = EnginePack.fromJson(
        {
          'schema': 1,
          'id': 'x',
          'name': 'X',
          'version': '1.0.0',
          'plugins': [
            {
              'id': 'bad',
              'name': 'Bad',
              'entry': 'bad.js',
              'kind': 'http',
            },
          ],
        },
        sourceUrl: manifestUrl,
      );
      await expectLater(
        PluginInstallValidator.validateBeforeCommit(
          manifestUrl: manifestUrl,
          manifest: pack.toJson(),
          pack: pack,
          scripts: const {'bad': 'function extract( {'},
          preludes: const {},
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('failed JS load'),
          ),
        ),
      );
    });

    test('optional integrity sha256 must match fetched body', () async {
      const manifestUrl = 'https://cdn.example/pack/manifest.json';
      const body = 'function extract() { return []; }';
      final digest =
          'sha256:${sha256.convert(utf8.encode(body)).toString()}';
      final pack = EnginePack.fromJson(
        {
          'schema': 1,
          'id': 'x',
          'name': 'X',
          'version': '1.0.0',
          'plugins': [
            {
              'id': 'p1',
              'name': 'P1',
              'entry': 'p1.js',
              'kind': 'http',
            },
          ],
        },
        sourceUrl: manifestUrl,
      );
      final manifest = {
        ...pack.toJson(),
        'integrity': {
          'scripts': {'p1': digest},
        },
      };
      PluginInstallValidator.debugSkipSmokeLoad = true;
      await expectLater(
        PluginInstallValidator.validateBeforeCommit(
          manifestUrl: manifestUrl,
          manifest: manifest,
          pack: pack,
          scripts: const {'p1': body},
          preludes: const {},
        ),
        completes,
      );
      await expectLater(
        PluginInstallValidator.validateBeforeCommit(
          manifestUrl: manifestUrl,
          manifest: manifest,
          pack: pack,
          scripts: const {'p1': '$body '},
          preludes: const {},
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('integrity mismatch'),
          ),
        ),
      );
    });
  });

  group('PluginRegistry install validation', () {
    late PluginRegistry registry;

    setUp(() {
      registry = PluginRegistry.instance;
      registry.debugHttpClient = null;
      SharedPreferences.setMockInitialValues({
        'engine_js_packs_v2_migrated': true,
        'engine_js_scripts_disk_v3_migrated': true,
      });
    });

    tearDown(() {
      registry.debugHttpClient = null;
    });

    test('refuses install before disk write when JS is invalid', () async {
      const url = 'https://cdn.example/bad-pack/manifest.json';
      registry.debugHttpClient = MockClient((req) async {
        final u = req.url.toString();
        if (u == url) {
          return http.Response(
            jsonEncode({
              'schema': 1,
              'id': 'bad-pack',
              'name': 'Bad',
              'version': '1.0.0',
              'plugins': [
                {
                  'id': 'broken',
                  'name': 'Broken',
                  'entry': 'broken.js',
                  'kind': 'http',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (u.endsWith('broken.js')) {
          return http.Response('function extract( {', 200);
        }
        return http.Response('not found', 404);
      });

      await expectLater(
        registry.install(url),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('install validation failed'),
          ),
        ),
      );
      expect(
        await PluginScriptDiskStore.loadEngineScript(
          sourceUrl: url,
          pluginId: 'broken',
        ),
        isNull,
      );
    });
  });
}
