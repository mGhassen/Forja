import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/plugin_script_disk_store.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('plugin_script_disk_');
    PluginScriptDiskStore.debugRoot = temp;
  });

  tearDown(() async {
    PluginScriptDiskStore.resetForTest();
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  test('save/load engine script + prelude', () async {
    const url = 'https://example.com/pack/manifest.json';
    await PluginScriptDiskStore.saveEngineScript(
      sourceUrl: url,
      pluginId: 'alpha',
      body: 'export const a = 1;',
    );
    await PluginScriptDiskStore.saveEnginePrelude(
      sourceUrl: url,
      preludeEntry: 'shared.js',
      body: 'const shared = true;',
    );
    expect(
      await PluginScriptDiskStore.hasEngineScript(
        sourceUrl: url,
        pluginId: 'alpha',
      ),
      isTrue,
    );
    expect(
      await PluginScriptDiskStore.loadEngineScript(
        sourceUrl: url,
        pluginId: 'alpha',
      ),
      'export const a = 1;',
    );
    expect(
      await PluginScriptDiskStore.loadEnginePrelude(
        sourceUrl: url,
        preludeEntry: 'shared.js',
      ),
      'const shared = true;',
    );
  });

  test('atomic replace overwrites script', () async {
    const url = 'https://example.com/pack/manifest.json';
    await PluginScriptDiskStore.saveEngineScript(
      sourceUrl: url,
      pluginId: 'alpha',
      body: 'v1',
    );
    await PluginScriptDiskStore.saveEngineScript(
      sourceUrl: url,
      pluginId: 'alpha',
      body: 'v2',
    );
    expect(
      await PluginScriptDiskStore.loadEngineScript(
        sourceUrl: url,
        pluginId: 'alpha',
      ),
      'v2',
    );
  });

  test('removeEnginePack deletes tree', () async {
    const url = 'https://example.com/pack/manifest.json';
    await PluginScriptDiskStore.saveEngineScript(
      sourceUrl: url,
      pluginId: 'alpha',
      body: 'x',
    );
    await PluginScriptDiskStore.removeEnginePack(url);
    expect(
      await PluginScriptDiskStore.hasEngineScript(
        sourceUrl: url,
        pluginId: 'alpha',
      ),
      isFalse,
    );
    final hash = PluginScriptDiskStore.packHash(url);
    final dir = Directory(
      p.join(
        temp.path,
        'accounts',
        'local',
        'profiles',
        'default',
        'engine',
        hash,
      ),
    );
    expect(await dir.exists(), isFalse);
  });

  test('nuvio scraper save/load/remove', () async {
    await PluginScriptDiskStore.saveNuvioScraper(
      scraperId: 'torrentio',
      body: 'module.exports = {}',
    );
    expect(await PluginScriptDiskStore.hasNuvioScraper('torrentio'), isTrue);
    expect(
      await PluginScriptDiskStore.loadNuvioScraper('torrentio'),
      'module.exports = {}',
    );
    await PluginScriptDiskStore.removeNuvioScraper('torrentio');
    expect(await PluginScriptDiskStore.hasNuvioScraper('torrentio'), isFalse);
  });

  test('safe filenames for prelude paths', () async {
    const url = 'https://a.example/manifest.json';
    await PluginScriptDiskStore.saveEnginePrelude(
      sourceUrl: url,
      preludeEntry: '../evil/path.js',
      body: 'ok',
    );
    final body = await PluginScriptDiskStore.loadEnginePrelude(
      sourceUrl: url,
      preludeEntry: '../evil/path.js',
    );
    expect(body, 'ok');
    final hash = PluginScriptDiskStore.packHash(url);
    final preludes = Directory(
      p.join(
        temp.path,
        'accounts',
        'local',
        'profiles',
        'default',
        'engine',
        hash,
        'preludes',
      ),
    );
    final names = preludes.listSync().map((e) => p.basename(e.path)).toList();
    expect(names, everyElement(matches(RegExp(r'^[a-f0-9]+\.js$'))));
  });

  test('scoped profiles isolate engine scripts', () async {
    const url = 'https://example.com/pack/manifest.json';
    await PluginScriptDiskStore.configureScope(
      accountId: 'acct-a',
      profileId: 'profile-1',
    );
    await PluginScriptDiskStore.saveEngineScript(
      sourceUrl: url,
      pluginId: 'alpha',
      body: 'profile-one',
    );

    await PluginScriptDiskStore.configureScope(
      accountId: 'acct-a',
      profileId: 'profile-2',
    );
    expect(
      await PluginScriptDiskStore.hasEngineScript(
        sourceUrl: url,
        pluginId: 'alpha',
      ),
      isFalse,
    );
    await PluginScriptDiskStore.saveEngineScript(
      sourceUrl: url,
      pluginId: 'alpha',
      body: 'profile-two',
    );

    await PluginScriptDiskStore.configureScope(
      accountId: 'acct-a',
      profileId: 'profile-1',
    );
    expect(
      await PluginScriptDiskStore.loadEngineScript(
        sourceUrl: url,
        pluginId: 'alpha',
      ),
      'profile-one',
    );
  });
}
