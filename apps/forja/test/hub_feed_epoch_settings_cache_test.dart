import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/cache/engine_cache.dart';
import 'package:forja/shared/engine/models/models.dart';
import 'package:forja/shared/engine/packs/registry/plugin_registry.dart';
import 'package:forja/shared/engine/packs/settings/pack_addon_settings_spec.dart';
import 'package:forja/shared/engine/packs/settings/pack_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    EngineCache.instance.wipeAll();
    PluginRegistry.debugResetHubOpenReload();
  });

  group('bumpHubFeedEpoch forceNetwork', () {
    test('defaults to force network (pack wipe / reload packs)', () {
      PluginRegistry.bumpHubFeedEpoch(pluginIds: ['hub-a']);
      expect(PluginRegistry.hubFeedEpochForceNetwork, isTrue);
      expect(PluginRegistry.hubFeedEpochTouches('hub-a'), isTrue);
    });

    test('pack settings can soft-rebind without force network', () {
      PluginRegistry.bumpHubFeedEpoch(
        pluginIds: ['hub-a'],
        forceNetwork: false,
      );
      expect(PluginRegistry.hubFeedEpochForceNetwork, isFalse);
      expect(PluginRegistry.hubNeedsReloadOnOpen('hub-a'), isFalse);
    });

    test('pack wipe flags the hub to reload on next open', () {
      PluginRegistry.bumpHubFeedEpoch(pluginIds: ['hub-a']);
      expect(PluginRegistry.hubNeedsReloadOnOpen('hub-a'), isTrue);
      expect(PluginRegistry.hubNeedsReloadOnOpen('hub-b'), isFalse);
      PluginRegistry.consumeHubReloadOnOpen('hub-a');
      expect(PluginRegistry.hubNeedsReloadOnOpen('hub-a'), isFalse);
    });

    test('pack wipe of every hub flags hubs that have not opened', () {
      PluginRegistry.bumpHubFeedEpoch(all: true);
      expect(PluginRegistry.hubNeedsReloadOnOpen('hub-a'), isTrue);
      PluginRegistry.consumeHubReloadOnOpen('hub-a');
      expect(PluginRegistry.hubNeedsReloadOnOpen('hub-a'), isFalse);
      expect(PluginRegistry.hubNeedsReloadOnOpen('hub-b'), isTrue);
    });
  });

  group('PackAddonSettingsField.reloadHub', () {
    test('defaults true', () {
      final field = PackAddonSettingsField.fromJson({
        'id': 'merge',
        'type': 'toggle',
        'label': 'Merge',
        'default': true,
      });
      expect(field, isNotNull);
      expect(field!.reloadHub, isTrue);
    });

    test('parses reloadHub false (open-mode paint only)', () {
      final field = PackAddonSettingsField.fromJson({
        'id': 'openMode',
        'type': 'select',
        'label': 'Open in',
        'default': 'panel',
        'reloadHub': false,
        'options': [
          {'id': 'panel', 'label': 'Panel'},
          {'id': 'details', 'label': 'Details'},
        ],
      });
      expect(field, isNotNull);
      expect(field!.reloadHub, isFalse);
    });
  });

  group('PackSettingsStore settings soft hub bump', () {
    test('setString with reloadHub keeps live feed cache slots', () async {
      const ns = 'live_sports.feed';
      EngineCache.instance.set(
        ns,
        'raw:all',
        {
          'rows': [
            {'id': 'm1', 'title': 'Match'},
          ],
          'at': 1,
        },
        ttl: const Duration(minutes: 15),
      );

      final before = PluginRegistry.hubFeedEpoch.value;
      await PackSettingsStore.setString(
        'hub-a',
        'mergeMatchingEvents',
        'true',
        reloadHub: true,
      );

      expect(PluginRegistry.hubFeedEpoch.value, greaterThan(before));
      expect(PluginRegistry.hubFeedEpochForceNetwork, isFalse);
      expect(PluginRegistry.hubFeedEpochTouches('hub-a'), isTrue);
      final hit = EngineCache.instance.get(ns, 'raw:all');
      expect(hit, isA<Map>());
      expect((hit as Map)['rows'], isNotEmpty);
    });

    test('reloadHub false only bumps revision', () async {
      const ns = 'live_sports.feed';
      EngineCache.instance.set(
        ns,
        'raw:all',
        {
          'rows': [
            {'id': 'm1'},
          ],
          'at': 1,
        },
        ttl: const Duration(minutes: 15),
      );

      final epochBefore = PluginRegistry.hubFeedEpoch.value;
      final revBefore = PackSettingsStore.revision.value;
      await PackSettingsStore.setString(
        'hub-a',
        'matchOpen',
        'details',
        reloadHub: false,
      );

      expect(PackSettingsStore.revision.value, greaterThan(revBefore));
      expect(PluginRegistry.hubFeedEpoch.value, epochBefore);
      expect(EngineCache.instance.get(ns, 'raw:all'), isNotNull);
    });
  });

  group('synthetic plugin field reloadHub', () {
    test('fromPlugin preserves reloadHub false', () {
      final plugin = EnginePlugin.fromJson({
        'id': 'test-hub-open',
        'name': 'Hub',
        'entry': 'h.js',
        'kind': 'catalog',
        'settings': {
          'group': 'Setup',
          'fields': [
            {
              'id': 'openMode',
              'type': 'select',
              'label': 'Open in',
              'default': 'panel',
              'reloadHub': false,
              'options': [
                {'id': 'panel', 'label': 'Panel'},
                {'id': 'details', 'label': 'Details'},
              ],
            },
          ],
        },
      });
      final spec = PackAddonSettingsSpec.fromPlugin(plugin);
      expect(spec, isNotNull);
      expect(spec!.fields.single.reloadHub, isFalse);
    });
  });
}
