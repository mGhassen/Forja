import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/plugin_install_coordinator.dart';
import 'package:forja/shared/engine/plugin_registry.dart';
import 'package:forja/shared/engine/plugin_script_disk_store.dart';
import 'package:forja/shell/shell_bus.dart';
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

  test('ensurePackScriptsReady refuses remote lean without user confirm', () async {
    const url = 'https://hydrate.example/manifest.json';
    SharedPreferences.setMockInitialValues({
      'engine_js_packs_v2': jsonEncode([
        {
          'sourceUrl': url,
          'packId': 'hydrate-pack',
          'name': 'Hydrate Pack',
          'version': '0.0.0',
          'plugins': const [],
        },
      ]),
      'engine_js_packs_v2_migrated': true,
      'engine_js_scripts_disk_v3_migrated': true,
    });
    final packs = await registry.listPacksRaw();
    expect(await registry.packNeedsDiskInstall(packs.first), isTrue);
    expect(await registry.ensurePackScriptsReady(packs.first), isFalse);
    expect(await registry.packNeedsDiskInstall(packs.first), isTrue);
  });

  test('ensurePluginReady does not prompt or download remote lean', () async {
    const url = 'https://prompt.example/manifest.json';
    SharedPreferences.setMockInitialValues({
      'engine_js_packs_v2': jsonEncode([
        {
          'sourceUrl': url,
          'packId': 'prompt-pack',
          'name': 'Prompt Pack',
          'version': '0.0.0',
          'plugins': [
            {
              'id': 'iptv-vod',
              'name': 'IPTV VOD',
              'entry': 'iptv_vod.js',
              'kind': 'catalog',
              'enabled': true,
            },
          ],
        },
      ]),
      'engine_js_packs_v2_migrated': true,
      'engine_js_scripts_disk_v3_migrated': true,
    });
    // Re-seed after setMockInitialValues wiped SharedPreferences instance.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'engine_js_packs_v2',
      jsonEncode([
        {
          'sourceUrl': url,
          'packId': 'prompt-pack',
          'name': 'Prompt Pack',
          'version': '0.0.0',
          'plugins': [
            {
              'id': 'iptv-vod',
              'name': 'IPTV VOD',
              'entry': 'iptv_vod.js',
              'kind': 'catalog',
              'enabled': true,
            },
          ],
        },
      ]),
    );

    expect(
      await PluginInstallCoordinator.instance.ensurePluginReady('iptv-vod'),
      isFalse,
    );
    expect(ShellBus.pendingPluginInstall.value, isNull);
    expect(ShellBus.pendingPluginBatchInstall.value, isNull);
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
        return http.Response('function extract(ctx) { return []; }', 200);
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
        notifyUpdates: false,
        awaitCloudLean: false,
        includeNuvio: false,
        promptBeforeInstall: false,
      );
    } finally {
      PluginInstallCoordinator.instance.progress.removeListener(listener);
    }

    expect(
      await PluginScriptDiskStore.loadEngineScript(
        sourceUrl: url,
        pluginId: 'p1',
      ),
      'function extract(ctx) { return []; }',
    );
    expect(seen.whereType<PluginInstallProgress>(), isNotEmpty);
    expect(PluginInstallCoordinator.instance.progress.value, isNull);
  });

  test('ensurePluginReady skips reinstall for local checkout packs', () async {
    final hubDir = await Directory.systemTemp.createTemp('coord_local_iptv_');
    addTearDown(() async {
      if (await hubDir.exists()) await hubDir.delete(recursive: true);
    });
    final manifestFile = File('${hubDir.path}/manifest.json');
    final entryFile = File('${hubDir.path}/iptv_vod.js');
    await entryFile.writeAsString(
      "function extract(ctx){ return hubOk('details', { meta: {} }); }",
    );
    await manifestFile.writeAsString(
      jsonEncode({
        'schema': 1,
        'id': 'forjahq-iptv-vod',
        'name': 'IPTV VOD',
        'version': '1.0.0',
        'plugins': [
          {
            'id': 'iptv-vod',
            'name': 'IPTV VOD Details',
            'entry': 'iptv_vod.js',
            'kind': 'catalog',
            'protocol': 1,
            'kit': 1,
            'types': ['iptv'],
            'capabilities': ['details'],
            'enabled': true,
          },
        ],
      }),
    );
    final url = manifestFile.path;

    SharedPreferences.setMockInitialValues({
      'engine_js_packs_v2_migrated': true,
      'engine_js_scripts_disk_v3_migrated': true,
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'engine_js_packs_v2',
      jsonEncode([
        {
          'sourceUrl': url,
          'packId': 'forjahq-iptv-vod',
          'name': 'IPTV VOD',
          'version': '1.0.0',
          'plugins': [
            {
              'id': 'iptv-vod',
              'name': 'IPTV VOD Details',
              'entry': 'iptv_vod.js',
              'kind': 'catalog',
              'protocol': 1,
              'kit': 1,
              'types': ['iptv'],
              'capabilities': ['details'],
              'enabled': true,
            },
          ],
        },
      ]),
    );

    final progressSeen = <PluginInstallProgress?>[];
    void listener() {
      progressSeen.add(PluginInstallCoordinator.instance.progress.value);
    }
    PluginInstallCoordinator.instance.progress.addListener(listener);
    try {
      expect(
        await PluginInstallCoordinator.instance.ensurePluginReady('iptv-vod'),
        isTrue,
      );
      expect(
        await PluginInstallCoordinator.instance.ensurePluginReady('iptv-vod'),
        isTrue,
      );
    } finally {
      PluginInstallCoordinator.instance.progress.removeListener(listener);
    }

    expect(progressSeen.whereType<PluginInstallProgress>(), isEmpty);
    expect(PluginInstallCoordinator.instance.progress.value, isNull);
  });

  test('ensureAllInstalled does not auto-update when manifest newer', () async {
    final hubDir = await Directory.systemTemp.createTemp('coord_local_hub_');
    addTearDown(() async {
      if (await hubDir.exists()) await hubDir.delete(recursive: true);
    });
    final manifestFile = File('${hubDir.path}/manifest.json');
    final entryFile = File('${hubDir.path}/p1.js');
    await entryFile.writeAsString('function extract(ctx) { return []; }');
    await manifestFile.writeAsString(
      jsonEncode({
        'schema': 1,
        'id': 'local-hub',
        'name': 'Local Hub',
        'version': '2.0.0',
        'plugins': [
          {
            'id': 'p1',
            'name': 'P1',
            'entry': 'p1.js',
            'kind': 'http',
          },
        ],
      }),
    );
    final url = manifestFile.path;

    SharedPreferences.setMockInitialValues({
      'engine_js_packs_v2_migrated': true,
      'engine_js_scripts_disk_v3_migrated': true,
      'nuvio_scripts_disk_v1_migrated': true,
      'nuvio_addons_kv_v1': '1',
      'nuvio_addons_v1': '[]',
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'engine_js_packs_v2',
      jsonEncode([
        {
          'sourceUrl': url,
          'packId': 'local-hub',
          'name': 'Local Hub',
          'version': '1.0.0',
          'plugins': [
            {
              'id': 'p1',
              'name': 'P1',
              'entry': 'p1.js',
              'kind': 'http',
              'enabled': true,
            },
          ],
        },
      ]),
    );

    await PluginInstallCoordinator.instance.ensureAllInstalled(
      notifyUpdates: false,
      awaitCloudLean: false,
      includeNuvio: false,
      promptBeforeInstall: false,
    );

    final packs = await registry.listPacksRaw();
    expect(packs, hasLength(1));
    expect(packs.first.version, '1.0.0');
    final pending = await registry.peekRemoteUpdate(packs.first);
    expect(pending?.remoteVersion, '2.0.0');
  });

  test('ensureAllInstalled skips local checkout when manifest version unchanged',
      () async {
    final hubDir = await Directory.systemTemp.createTemp('coord_local_same_');
    addTearDown(() async {
      if (await hubDir.exists()) await hubDir.delete(recursive: true);
    });
    final manifestFile = File('${hubDir.path}/manifest.json');
    final entryFile = File('${hubDir.path}/p1.js');
    await entryFile.writeAsString('function extract(ctx) { return []; }');
    await manifestFile.writeAsString(
      jsonEncode({
        'schema': 1,
        'id': 'local-hub',
        'name': 'Local Hub',
        'version': '1.0.0',
        'plugins': [
          {
            'id': 'p1',
            'name': 'P1',
            'entry': 'p1.js',
            'kind': 'http',
          },
        ],
      }),
    );
    final url = manifestFile.path;

    SharedPreferences.setMockInitialValues({
      'engine_js_packs_v2_migrated': true,
      'engine_js_scripts_disk_v3_migrated': true,
      'nuvio_scripts_disk_v1_migrated': true,
      'nuvio_addons_kv_v1': '1',
      'nuvio_addons_v1': '[]',
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'engine_js_packs_v2',
      jsonEncode([
        {
          'sourceUrl': url,
          'packId': 'local-hub',
          'name': 'Local Hub',
          'version': '1.0.0',
          'plugins': [
            {
              'id': 'p1',
              'name': 'P1',
              'entry': 'p1.js',
              'kind': 'http',
              'enabled': true,
            },
          ],
        },
      ]),
    );

    final seen = <PluginInstallProgress?>[];
    void listener() {
      seen.add(PluginInstallCoordinator.instance.progress.value);
    }

    PluginInstallCoordinator.instance.progress.addListener(listener);
    try {
      await PluginInstallCoordinator.instance.ensureAllInstalled(
        notifyUpdates: false,
        awaitCloudLean: false,
        includeNuvio: false,
        promptBeforeInstall: false,
      );
    } finally {
      PluginInstallCoordinator.instance.progress.removeListener(listener);
    }

    expect(
      seen
          .whereType<PluginInstallProgress>()
          .map((p) => p.label)
          .where((l) => l.toLowerCase().startsWith('fetching')),
      isEmpty,
    );
    expect(PluginInstallCoordinator.instance.progress.value, isNull);
    final packs = await registry.listPacksRaw();
    expect(packs.first.version, '1.0.0');
  });

  test('peekRemoteUpdate detects newer local manifest version', () async {
    final hubDir = await Directory.systemTemp.createTemp('coord_local_newer_');
    addTearDown(() async {
      if (await hubDir.exists()) await hubDir.delete(recursive: true);
    });
    final manifestFile = File('${hubDir.path}/manifest.json');
    await File('${hubDir.path}/p1.js')
        .writeAsString('function extract(ctx) { return []; }');
    await manifestFile.writeAsString(
      jsonEncode({
        'schema': 1,
        'id': 'local-live',
        'name': 'Local Live',
        'version': '1.7.0',
        'plugins': [
          {
            'id': 'p1',
            'name': 'P1',
            'entry': 'p1.js',
            'kind': 'http',
          },
        ],
      }),
    );
    final url = manifestFile.path;

    SharedPreferences.setMockInitialValues({
      'engine_js_packs_v2_migrated': true,
      'engine_js_scripts_disk_v3_migrated': true,
      'engine_js_packs_v2': jsonEncode([
        {
          'sourceUrl': url,
          'packId': 'local-live',
          'name': 'Local Live',
          'version': '1.6.0',
          'plugins': [
            {
              'id': 'p1',
              'name': 'P1',
              'entry': 'p1.js',
              'kind': 'http',
              'enabled': true,
            },
          ],
        },
      ]),
    });

    final packs = await registry.listPacksRaw();
    final update = await registry.peekRemoteUpdate(packs.first);
    expect(update, isNotNull);
    expect(update!.installedVersion, '1.6.0');
    expect(update.remoteVersion, '1.7.0');
  });
}
