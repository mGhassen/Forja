import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/plugin_install_coordinator.dart';
import 'package:forja/shared/engine/plugin_registry.dart';
import 'package:forja/shared/engine/plugin_script_disk_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory diskRoot;
  late PluginRegistry registry;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'engine_js_packs_v2_migrated': true,
      'engine_js_scripts_disk_v3_migrated': true,
      'nuvio_scripts_disk_v1_migrated': true,
      'nuvio_addons_kv_v1': '1',
    });
    diskRoot = await Directory.systemTemp.createTemp('coord_disk_');
    PluginScriptDiskStore.debugRoot = diskRoot;
    registry = PluginRegistry.instance;
    registry.debugHttpClient = null;
  });

  tearDown(() async {
    registry.debugHttpClient = null;
    PluginScriptDiskStore.resetForTest();
    if (await diskRoot.exists()) {
      await diskRoot.delete(recursive: true);
    }
  });

  test('packNeedsDiskInstall true for lean stub', () async {
    const url = 'https://lean.example/manifest.json';
    SharedPreferences.setMockInitialValues({
      'engine_js_packs_v2': jsonEncode([
        {
          'sourceUrl': url,
          'packId': 'lean',
          'name': 'Lean',
          'version': '0.0.0',
          'plugins': const [],
        },
      ]),
      'engine_js_packs_v2_migrated': true,
      'engine_js_scripts_disk_v3_migrated': true,
    });
    final packs = await registry.listPacksRaw();
    expect(await registry.packNeedsDiskInstall(packs.first), isTrue);
  });

  test('ensureAllInstalled installs missing lean pack with progress', () async {
    const url = 'https://coord.example/manifest.json';
    SharedPreferences.setMockInitialValues({
      'engine_js_packs_v2': jsonEncode([
        {
          'sourceUrl': url,
          'packId': 'coord',
          'name': 'Coord Pack',
          'version': '0.0.0',
          'plugins': const [],
        },
      ]),
      'engine_js_packs_v2_migrated': true,
      'engine_js_scripts_disk_v3_migrated': true,
      'nuvio_scripts_disk_v1_migrated': true,
      'nuvio_addons_kv_v1': '1',
      'nuvio_addons_v1': '[]',
    });
    // Re-seed after setMockInitialValues wiped SharedPreferences instance.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'engine_js_packs_v2',
      jsonEncode([
        {
          'sourceUrl': url,
          'packId': 'coord',
          'name': 'Coord Pack',
          'version': '0.0.0',
          'plugins': const [],
        },
      ]),
    );

    registry.debugHttpClient = MockClient((req) async {
      final u = req.url.toString();
      if (u == url) {
        return http.Response(
          jsonEncode({
            'schema': 1,
            'id': 'coord',
            'name': 'Coord Pack',
            'version': '1.2.0',
            'plugins': [
              {
                'id': 'p1',
                'name': 'P1',
                'entry': 'p1.js',
                'kind': 'http',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (u.endsWith('p1.js')) {
        return http.Response('export default 1', 200);
      }
      return http.Response('nf', 404);
    });

    final seen = <PluginInstallProgress?>[];
    void listener() {
      seen.add(PluginInstallCoordinator.instance.progress.value);
    }

    PluginInstallCoordinator.instance.progress.addListener(listener);
    try {
      await PluginInstallCoordinator.instance.ensureAllInstalled(
        checkUpdates: false,
        awaitCloudLean: false,
        includeNuvio: false,
      );
    } finally {
      PluginInstallCoordinator.instance.progress.removeListener(listener);
    }

    expect(
      await PluginScriptDiskStore.loadEngineScript(
        sourceUrl: url,
        pluginId: 'p1',
      ),
      'export default 1',
    );
    expect(seen.whereType<PluginInstallProgress>(), isNotEmpty);
    expect(PluginInstallCoordinator.instance.progress.value, isNull);
  });
}
