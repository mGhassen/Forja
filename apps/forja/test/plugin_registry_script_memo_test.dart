import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remote pack scripts are read from disk once per process and served from
/// memory until the pack index is rewritten (install / remove). Keeps the
/// green Play race off the disk when dozens of providers start at once.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory diskRoot;
  late PluginRegistry registry;

  const url = 'https://memo.example/manifest.json';
  const pluginId = 'test-provider-a';

  Map<String, Object?> packIndex({String prelude = ''}) => {
    'sourceUrl': url,
    'packId': 'memo-pack',
    'name': 'Memo Pack',
    'version': '1.0.0',
    if (prelude.isNotEmpty) 'prelude': prelude,
    'plugins': [
      {
        'id': pluginId,
        'name': 'Provider A',
        'entry': 'a.js',
        'kind': 'http',
        'enabled': true,
      },
    ],
  };

  /// Drop the singleton's pack memo left by a previous test (any index write
  /// clears it), then install this test's index so the next read is fresh.
  Future<void> installIndex(Map<String, Object?> pack) async {
    const throwaway = 'https://throwaway.example/manifest.json';
    SharedPreferences.setMockInitialValues({
      PluginRegistry.packsPrefsKey: jsonEncode([
        {
          'sourceUrl': throwaway,
          'packId': 'throwaway',
          'name': 'Throwaway',
          'version': '0.0.0',
          'plugins': const [],
        },
      ]),
      'engine_js_packs_v2_migrated': true,
      'engine_js_scripts_disk_v3_migrated': true,
    });
    await PluginRegistry.instance.removePack(throwaway, purgeDisk: false);
    SharedPreferences.setMockInitialValues({
      PluginRegistry.packsPrefsKey: jsonEncode([pack]),
      'engine_js_packs_v2_migrated': true,
      'engine_js_scripts_disk_v3_migrated': true,
      'nuvio_scripts_disk_v1_migrated': true,
      'nuvio_addons_kv_v1': '1',
    });
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LocalDataScope.resetForTest();
    await LocalDataScope.configure(accountId: null, profileId: null);
    diskRoot = await Directory.systemTemp.createTemp('memo_disk_');
    PluginScriptDiskStore.resetForTest();
    PluginScriptDiskStore.debugRoot = diskRoot;
    await PluginScriptDiskStore.configureScope(
      accountId: null,
      profileId: null,
    );
    registry = PluginRegistry.instance;
    await installIndex(packIndex());
  });

  tearDown(() async {
    PluginScriptDiskStore.resetForTest();
    if (await diskRoot.exists()) {
      await diskRoot.delete(recursive: true);
    }
  });

  test('second load is served from memory, not disk', () async {
    await PluginScriptDiskStore.saveEngineScript(
      sourceUrl: url,
      pluginId: pluginId,
      body: 'v1',
    );
    final plugin = (await registry.listPacksRaw()).single.plugins.single;

    expect(await registry.loadScript(sourceUrl: url, plugin: plugin), 'v1');

    // Disk changes outside the registry are not seen until the index changes.
    await PluginScriptDiskStore.saveEngineScript(
      sourceUrl: url,
      pluginId: pluginId,
      body: 'v2',
    );
    expect(await registry.loadScript(sourceUrl: url, plugin: plugin), 'v1');
  });

  test('pack index write drops the memo', () async {
    await PluginScriptDiskStore.saveEngineScript(
      sourceUrl: url,
      pluginId: pluginId,
      body: 'v1',
    );
    final plugin = (await registry.listPacksRaw()).single.plugins.single;
    expect(await registry.loadScript(sourceUrl: url, plugin: plugin), 'v1');

    await PluginScriptDiskStore.saveEngineScript(
      sourceUrl: url,
      pluginId: pluginId,
      body: 'v2',
    );
    // removePack rewrites the index (and purges this pack's scripts); the
    // next load for the same plugin must go back to disk.
    await registry.removePack(url, purgeDisk: false);
    expect(await registry.loadScript(sourceUrl: url, plugin: plugin), 'v2');
  });

  test('missing script is not memoised as empty', () async {
    final plugin = (await registry.listPacksRaw()).single.plugins.single;
    expect(await registry.loadScript(sourceUrl: url, plugin: plugin), isNull);

    await PluginScriptDiskStore.saveEngineScript(
      sourceUrl: url,
      pluginId: pluginId,
      body: 'late',
    );
    expect(await registry.loadScript(sourceUrl: url, plugin: plugin), 'late');
  });

  test('shared prelude is read once and prepended for every plugin', () async {
    await installIndex(packIndex(prelude: '_kit.js'));
    await PluginScriptDiskStore.saveEnginePrelude(
      sourceUrl: url,
      preludeEntry: '_kit.js',
      body: 'PRE',
    );
    await PluginScriptDiskStore.saveEngineScript(
      sourceUrl: url,
      pluginId: pluginId,
      body: 'BODY',
    );
    final pack = (await registry.listPacksRaw()).single;
    final plugin = pack.plugins.single;

    final first = await registry.loadScript(
      sourceUrl: url,
      plugin: plugin,
      packPrelude: pack.prelude,
    );
    expect(first, 'PRE\nBODY');

    await PluginScriptDiskStore.saveEnginePrelude(
      sourceUrl: url,
      preludeEntry: '_kit.js',
      body: 'CHANGED',
    );
    final second = await registry.loadScript(
      sourceUrl: url,
      plugin: plugin,
      packPrelude: pack.prelude,
    );
    expect(second, 'PRE\nBODY', reason: 'prelude served from memory');
  });

  test(
    'listPacks verifies a pack on disk once, then stops stat-ing it',
    () async {
      await PluginScriptDiskStore.saveEngineScript(
        sourceUrl: url,
        pluginId: pluginId,
        body: 'v1',
      );
      expect(
        await registry.packNeedsDiskInstall(
          (await registry.listPacksRaw()).single,
        ),
        isFalse,
        reason: 'fixture script is on disk before the first listPacks',
      );
      final log = <String>[];
      final prior = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) log.add(message);
      };
      try {
        await registry.listPacks();
        expect(
          log.where((l) => l.contains('scripts missing')),
          isEmpty,
          reason: 'script is on disk at the first listPacks',
        );
        // Delete the script behind the registry's back: a re-stat would now
        // log "scripts missing"; the verified memo keeps listPacks off disk.
        await PluginScriptDiskStore.removeEnginePack(url);
        final packs = await registry.listPacks();
        expect(packs.map((p) => p.sourceUrl), [url]);
        expect(log.where((l) => l.contains('scripts missing')), isEmpty);
      } finally {
        debugPrint = prior;
      }
      expect(
        await registry.packNeedsDiskInstall(
          (await registry.listPacksRaw()).single,
        ),
        isTrue,
        reason: 'direct check still sees the disk truth',
      );
    },
  );
}
