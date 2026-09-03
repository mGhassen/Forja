import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/sync/src/sync_domain_bridge.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, Object> _basePrefs(List<Map<String, dynamic>> packs) => {
      'engine_js_packs_v2': jsonEncode(packs),
      'engine_js_packs_v2_migrated': true,
      'engine_js_scripts_disk_v3_migrated': true,
      'engine_js_legacy_forjahq_wiped': true,
      'nuvio_scripts_disk_v1_migrated': true,
    };

Future<void> _seedPacks(List<Map<String, dynamic>> packs) async {
  SharedPreferences.setMockInitialValues(_basePrefs(packs));
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('engine_js_packs_v2', jsonEncode(packs));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(_basePrefs(const []));
    ShellBus.resetPluginInstallQueueForTest();
    PluginInstallCoordinator.debugSetBootWarm(false);
    await DeferredRemoteInstallStore.clearAll();
    await PendingRemotePurgeStore.clearAll();
  });

  tearDown(() {
    ShellBus.resetPluginInstallQueueForTest();
    PluginInstallCoordinator.debugSetBootWarm(false);
  });

  group('applyLeanManifestUrls', () {
    test('returns newly added remote URLs', () async {
      await _seedPacks(const []);
      final result = await PluginRegistry.instance.applyLeanManifestUrls([
        {
          'manifestUrl': 'https://cdn.example/pack/manifest.json',
          'name': 'Remote Pack',
        },
      ]);
      expect(result.added, hasLength(1));
      expect(result.added.first.manifestUrl, 'https://cdn.example/pack/manifest.json');
      expect(result.added.first.name, 'Remote Pack');
      expect(result.removed, isEmpty);
      final packs = await PluginRegistry.instance.listPacksRaw();
      expect(packs.single.plugins, isEmpty);
    });

    test('mid-session keeps installed pack and reports removed', () async {
      await _seedPacks([
        {
          'sourceUrl': '/tmp/forja-keep/manifest.json',
          'packId': 'keep',
          'name': 'Keep',
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
      ]);
      final result = await PluginRegistry.instance.applyLeanManifestUrls(
        const [],
        purgeRemovedImmediately: false,
      );
      expect(result.removed, hasLength(1));
      expect(result.removed.first.manifestUrl, '/tmp/forja-keep/manifest.json');
      final packs = await PluginRegistry.instance.listPacksRaw();
      expect(packs, hasLength(1));
    });

    test('boot purges missing user packs immediately', () async {
      await _seedPacks([
        {
          'sourceUrl': '/tmp/forja-drop/manifest.json',
          'packId': 'drop',
          'name': 'Drop',
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
      ]);
      final result = await PluginRegistry.instance.applyLeanManifestUrls(
        const [],
        purgeRemovedImmediately: true,
      );
      expect(result.removed, hasLength(1));
      expect(await PluginRegistry.instance.listPacksRaw(), isEmpty);
    });

    test('lean stub removed from cloud is dropped without uninstall prompt',
        () async {
      await _seedPacks([
        {
          'sourceUrl': 'https://cdn.example/stub/manifest.json',
          'packId': 'stub',
          'name': 'Stub',
          'version': '0.0.0',
          'plugins': const [],
        },
      ]);
      final result = await PluginRegistry.instance.applyLeanManifestUrls(
        const [],
        purgeRemovedImmediately: false,
      );
      expect(result.removed, isEmpty);
      expect(await PluginRegistry.instance.listPacksRaw(), isEmpty);
    });

    test('re-adding a cloud row clears pending purge', () async {
      const url = '/tmp/forja-purge/manifest.json';
      await _seedPacks([
        {
          'sourceUrl': url,
          'packId': 'purge',
          'name': 'Purge',
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
      ]);
      await PendingRemotePurgeStore.defer(url);
      expect(await PendingRemotePurgeStore.contains(url), isTrue);
      await PluginRegistry.instance.applyLeanManifestUrls([
        {'manifestUrl': url, 'name': 'Purge'},
      ], purgeRemovedImmediately: false);
      expect(await PendingRemotePurgeStore.contains(url), isFalse);
    });
  });

  group('resolvePackDeviceState', () {
    test('pending purge wins over local pack', () async {
      const url = '/tmp/forja-state/manifest.json';
      await _seedPacks([
        {
          'sourceUrl': url,
          'packId': 'state',
          'name': 'State',
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
      ]);
      await PendingRemotePurgeStore.defer(url);
      final pack = (await PluginRegistry.instance.listPacksRaw()).single;
      final snap = await resolvePackDeviceState(
        manifestUrl: url,
        localPack: pack,
      );
      expect(snap.state, PackDeviceState.pendingPurge);
    });

    test('lean stub is pending download unless deferred', () async {
      const url = 'https://cdn.example/lean/manifest.json';
      await _seedPacks([
        {
          'sourceUrl': url,
          'packId': 'lean',
          'name': 'Lean',
          'version': '0.0.0',
          'plugins': const [],
        },
      ]);
      final pack = (await PluginRegistry.instance.listPacksRaw()).single;
      var snap = await resolvePackDeviceState(
        manifestUrl: url,
        localPack: pack,
      );
      expect(snap.state, PackDeviceState.onProfileLean);
      await DeferredRemoteInstallStore.defer(url);
      snap = await resolvePackDeviceState(
        manifestUrl: url,
        localPack: pack,
      );
      expect(snap.state, PackDeviceState.deferred);
    });
  });

  group('PluginInstallPromptService', () {
    test('enqueues install for added packs', () async {
      await _seedPacks(const []);
      await PluginInstallPromptService.enqueueFromLeanDiff(
        const LeanApplyResult(
          added: [
            LeanPackDelta(
              manifestUrl: 'https://cdn.example/new/manifest.json',
              name: 'New Pack',
            ),
          ],
        ),
      );
      expect(ShellBus.pendingPluginInstallQueue.value, hasLength(1));
      final prompt = ShellBus.takeNextPluginInstall();
      expect(prompt?.kind, PluginPackPromptKind.install);
      expect(prompt?.source, PluginInstallSource.remoteProfile);
      expect(prompt?.manifestUrl, 'https://cdn.example/new/manifest.json');
    });

    test('skips deferred install URLs', () async {
      const url = 'https://cdn.example/later/manifest.json';
      await DeferredRemoteInstallStore.defer(url);
      await PluginInstallPromptService.enqueueFromLeanDiff(
        const LeanApplyResult(
          added: [LeanPackDelta(manifestUrl: url, name: 'Later')],
        ),
      );
      expect(ShellBus.pendingPluginInstallQueue.value, isEmpty);
    });

    test('skips already pending-purge uninstalls', () async {
      const url = '/tmp/forja-gone/manifest.json';
      await _seedPacks([
        {
          'sourceUrl': url,
          'packId': 'gone',
          'name': 'Gone',
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
      ]);
      await PendingRemotePurgeStore.defer(url);
      await PluginInstallPromptService.enqueueFromLeanDiff(
        const LeanApplyResult(
          removed: [LeanPackDelta(manifestUrl: url, name: 'Gone')],
        ),
      );
      expect(ShellBus.pendingPluginInstallQueue.value, isEmpty);
    });

    test('skips install prompt for local packs already on disk', () async {
      const url = '/tmp/forja-ready/manifest.json';
      await _seedPacks([
        {
          'sourceUrl': url,
          'packId': 'ready',
          'name': 'Ready',
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
      ]);
      await PluginInstallPromptService.enqueueFromLeanDiff(
        const LeanApplyResult(
          added: [LeanPackDelta(manifestUrl: url, name: 'Ready')],
        ),
      );
      expect(ShellBus.pendingPluginInstallQueue.value, isEmpty);
    });

    test('skips enqueue during boot warm', () async {
      PluginInstallCoordinator.debugSetBootWarm(true);
      await PluginInstallPromptService.enqueueFromLeanDiff(
        const LeanApplyResult(
          added: [
            LeanPackDelta(
              manifestUrl: 'https://cdn.example/boot/manifest.json',
              name: 'Boot',
            ),
          ],
        ),
      );
      expect(ShellBus.pendingPluginInstallQueue.value, isEmpty);
    });

    test('FIFO mixed install and uninstall', () async {
      await _seedPacks([
        {
          'sourceUrl': '/tmp/forja-gone/manifest.json',
          'packId': 'gone',
          'name': 'Gone',
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
      ]);
      await PluginInstallPromptService.enqueueFromLeanDiff(
        const LeanApplyResult(
          added: [
            LeanPackDelta(
              manifestUrl: 'https://cdn.example/a/manifest.json',
              name: 'A',
            ),
          ],
          removed: [
            LeanPackDelta(
              manifestUrl: '/tmp/forja-gone/manifest.json',
              name: 'Gone',
            ),
          ],
        ),
      );
      expect(ShellBus.pendingPluginInstallQueue.value, hasLength(2));
      final first = ShellBus.takeNextPluginInstall();
      final second = ShellBus.takeNextPluginInstall();
      expect(first?.kind, PluginPackPromptKind.install);
      expect(second?.kind, PluginPackPromptKind.uninstall);
      expect(ShellBus.takeNextPluginInstall(), isNull);
    });
  });

  group('Forja export', () {
    test('omits pending-purge URLs', () async {
      const url = '/tmp/forja-export/manifest.json';
      await _seedPacks([
        {
          'sourceUrl': url,
          'packId': 'export',
          'name': 'Export',
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
      ]);
      await PendingRemotePurgeStore.defer(url);
      final compact = await SyncDomainBridge.instance.exportForja();
      expect(compact['packs'], isNull);
    });
  });
}
