import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/sync/bridge/sync_domain_bridge.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
  late Directory diskRoot;

  setUp(() async {
    SharedPreferences.setMockInitialValues(_basePrefs(const []));
    diskRoot = await Directory.systemTemp.createTemp('remote_profile_');
    PluginScriptDiskStore.debugRoot = diskRoot;
    ShellBus.resetPluginInstallQueueForTest();
    ShellBus.splashDismissed.value = true;
    PluginInstallCoordinator.debugSetBootWarm(false);
    await DeferredRemoteInstallStore.clearAll();
    await PendingRemotePurgeStore.clearAll();
  });

  tearDown(() async {
    ShellBus.resetPluginInstallQueueForTest();
    PluginInstallCoordinator.debugSetBootWarm(false);
    PluginRegistry.instance.debugHttpClient = null;
    PluginScriptDiskStore.resetForTest();
    if (await diskRoot.exists()) {
      await diskRoot.delete(recursive: true);
    }
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

    test('rewrites ForjaHQ Mac checkout path to official remote', () async {
      await _seedPacks(const []);
      final result = await PluginRegistry.instance.applyLeanManifestUrls([
        {
          'manifestUrl':
              '/Users/dev/Workspace/Forja/plugins/hubs/live_sports_cards/manifest.json',
          'name': 'Live Sports Cards',
        },
      ]);
      expect(result.added, hasLength(1));
      expect(
        result.added.first.manifestUrl,
        officialManifestUrlForSlot('live_sports_cards'),
      );
      final packs = await PluginRegistry.instance.listPacksRaw();
      expect(packs.single.sourceUrl, officialManifestUrlForSlot('live_sports_cards'));
    });

    test('keeps local ForjaHQ checkout when cloud has official URL', () async {
      const local =
          '/Users/dev/Workspace/Forja/plugins/hubs/shahid/manifest.json';
      final official = officialManifestUrlForSlot('shahid')!;
      await _seedPacks([
        {
          'sourceUrl': local,
          'packId': 'shahid',
          'name': 'ForjaHQ Shahid',
          'version': '1.0.0',
          'plugins': [
            {
              'id': 'shahid-hub',
              'name': 'Shahid',
              'entry': 'shahid.js',
              'kind': 'http',
            },
          ],
        },
      ]);
      final result = await PluginRegistry.instance.applyLeanManifestUrls([
        {'manifestUrl': official, 'name': 'ForjaHQ Shahid'},
      ]);
      expect(result.added, isEmpty);
      expect(result.removed, isEmpty);
      final packs = await PluginRegistry.instance.listPacksRaw();
      expect(packs, hasLength(1));
      expect(packs.single.sourceUrl, local);
      expect(packs.single.plugins, isNotEmpty);
    });

    test('skips non-ForjaHQ local paths from cloud lean', () async {
      await _seedPacks(const []);
      final result = await PluginRegistry.instance.applyLeanManifestUrls([
        {
          'manifestUrl': '/tmp/my-custom-pack/manifest.json',
          'name': 'Custom',
        },
      ]);
      expect(result.added, isEmpty);
      expect(await PluginRegistry.instance.listPacksRaw(), isEmpty);
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
      const url = 'https://cdn.example/purge/manifest.json';
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
    test('auto-installs added packs without batch prompt', () async {
      const url = 'https://cdn.example/new/manifest.json';
      await _seedPacks([
        {
          'sourceUrl': url,
          'packId': 'new',
          'name': 'New Pack',
          'version': '0.0.0',
          'plugins': const [],
        },
      ]);
      PluginRegistry.instance.debugHttpClient = MockClient((req) async {
        final path = req.url.path;
        if (path.endsWith('manifest.json')) {
          return http.Response(
            jsonEncode({
              'schema': 1,
              'id': 'new',
              'name': 'New Pack',
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
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path.endsWith('p1.js')) {
          return http.Response(
            'function extract(ctx) { return []; }',
            200,
            headers: {'content-type': 'text/javascript'},
          );
        }
        return http.Response('nf', 404);
      });

      await PluginInstallPromptService.applyCloudLeanDiff(
        const LeanApplyResult(
          added: [
            LeanPackDelta(
              manifestUrl: url,
              name: 'New Pack',
            ),
          ],
        ),
      );
      expect(ShellBus.pendingPluginInstallQueue.value, isEmpty);
      expect(ShellBus.pendingPluginBatchInstall.value, isNull);
      expect(
        await PluginScriptDiskStore.loadEngineScript(
          sourceUrl: url,
          pluginId: 'p1',
        ),
        'function extract(ctx) { return []; }',
      );
    });

    test('skips install when pack already on disk', () async {
      final dir = Directory.systemTemp.createTempSync('forja-ready-');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final file = File('${dir.path}/manifest.json');
      await file.writeAsString(
        jsonEncode({
          'id': 'ready',
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
        }),
      );
      final url = file.path;
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
      var fetched = false;
      PluginRegistry.instance.debugHttpClient = MockClient((req) async {
        fetched = true;
        return http.Response('nf', 404);
      });
      await PluginInstallPromptService.applyCloudLeanDiff(
        LeanApplyResult(
          added: [LeanPackDelta(manifestUrl: url, name: 'Ready')],
        ),
      );
      expect(fetched, isFalse);
      expect(ShellBus.pendingPluginBatchInstall.value, isNull);
    });

    test('skips during boot warm', () async {
      PluginInstallCoordinator.debugSetBootWarm(true);
      var fetched = false;
      PluginRegistry.instance.debugHttpClient = MockClient((req) async {
        fetched = true;
        return http.Response('nf', 404);
      });
      await PluginInstallPromptService.applyCloudLeanDiff(
        const LeanApplyResult(
          added: [
            LeanPackDelta(
              manifestUrl: 'https://cdn.example/boot/manifest.json',
              name: 'Boot',
            ),
          ],
        ),
      );
      expect(fetched, isFalse);
      expect(ShellBus.pendingPluginBatchInstall.value, isNull);
    });

    test('does not enqueue uninstall confirm for removed packs', () async {
      await _seedPacks(const []);
      await PluginInstallPromptService.applyCloudLeanDiff(
        const LeanApplyResult(
          removed: [
            LeanPackDelta(
              manifestUrl: '/tmp/forja-gone/manifest.json',
              name: 'Gone',
            ),
          ],
        ),
      );
      expect(ShellBus.pendingPluginInstallQueue.value, isEmpty);
      expect(ShellBus.pendingPluginBatchInstall.value, isNull);
    });
  });

  group('exportForjaCompact omits pending-purge URLs', () {
    test('pending purge packs are not exported', () async {
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
      final payload = await SyncDomainBridge.instance.exportForja();
      final packs = payload['packs'] as List? ?? const [];
      expect(packs, isEmpty);
    });

    test('skips unpublished local ForjaHQ rewrite when GitHub 404', () async {
      const local =
          '/Users/dev/Workspace/Forja/plugins/hubs/shahid/manifest.json';
      final official = officialManifestUrlForSlot('shahid')!;
      await _seedPacks([
        {
          'sourceUrl': local,
          'packId': 'shahid',
          'name': 'ForjaHQ Shahid',
          'version': '1.0.0',
          'plugins': [
            {
              'id': 'shahid-hub',
              'name': 'Shahid',
              'entry': 'shahid.js',
              'kind': 'http',
            },
          ],
        },
      ]);
      PluginRegistry.instance.debugHttpClient = MockClient((req) async {
        expect(req.url.toString(), official);
        return http.Response('not found', 404);
      });
      final payload = await SyncDomainBridge.instance.exportForja();
      final packs = payload['packs'] as List? ?? const [];
      expect(packs, isEmpty);
    });

    test('exports published local ForjaHQ as official URL', () async {
      const local =
          '/Users/dev/Workspace/Forja/plugins/hubs/live_sports/manifest.json';
      final official = officialManifestUrlForSlot('live_sports')!;
      await _seedPacks([
        {
          'sourceUrl': local,
          'packId': 'live_sports',
          'name': 'ForjaHQ Live Sports',
          'version': '1.2.0',
          'plugins': [
            {
              'id': 'live-sports-hub',
              'name': 'Live Sports',
              'entry': 'live_sports.js',
              'kind': 'http',
            },
          ],
        },
      ]);
      PluginRegistry.instance.debugHttpClient = MockClient((req) async {
        expect(req.url.toString(), official);
        return http.Response(
          jsonEncode({'version': '9.9.9', 'name': 'ForjaHQ Live Sports'}),
          200,
        );
      });
      final payload = await SyncDomainBridge.instance.exportForja();
      final packs = (payload['packs'] as List).cast<Map>();
      expect(packs, hasLength(1));
      expect(packs.single['manifestUrl'], official);
      expect(packs.single['version'], '1.2.0');
    });
  });
}
