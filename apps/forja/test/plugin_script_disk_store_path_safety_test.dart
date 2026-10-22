import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/packs/registry/plugin_script_disk_store.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('plugin_disk_safety_');
    PluginScriptDiskStore.debugRoot = temp;
  });

  tearDown(() async {
    PluginScriptDiskStore.resetForTest();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('isSafePluginId mirrors the manifest charset', () {
    expect(PluginScriptDiskStore.isSafePluginId('test-provider-a'), isTrue);
    expect(PluginScriptDiskStore.isSafePluginId('../x'), isFalse);
    expect(PluginScriptDiskStore.isSafePluginId('a/b'), isFalse);
    expect(PluginScriptDiskStore.isSafePluginId(''), isFalse);
    expect(PluginScriptDiskStore.isSafePluginId('ünicode'), isFalse);
  });

  test('traversal plugin id writes nothing outside the pack dir', () async {
    const url = 'https://example.test/pack/manifest.json';
    await expectLater(
      PluginScriptDiskStore.saveEngineScript(
        sourceUrl: url,
        pluginId: '../../escaped',
        body: 'evil',
      ),
      throwsA(isA<ArgumentError>()),
    );
    final escaped = <String>[];
    await for (final e in temp.list(recursive: true)) {
      if (e is File && p.basename(e.path).contains('escaped')) {
        escaped.add(e.path);
      }
    }
    expect(escaped, isEmpty);
    expect(
      await PluginScriptDiskStore.hasEngineScript(
        sourceUrl: url,
        pluginId: '../../escaped',
      ),
      isFalse,
    );
    expect(
      await PluginScriptDiskStore.loadEngineScript(
        sourceUrl: url,
        pluginId: 'a/b',
      ),
      isNull,
    );
  });

  test('safe id still round-trips under plugins/', () async {
    const url = 'https://example.test/pack/manifest.json';
    await PluginScriptDiskStore.saveEngineScript(
      sourceUrl: url,
      pluginId: 'test-provider-a',
      body: 'ok',
    );
    expect(
      await PluginScriptDiskStore.loadEngineScript(
        sourceUrl: url,
        pluginId: 'test-provider-a',
      ),
      'ok',
    );
  });
}
