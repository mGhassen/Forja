import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/settings/addons/catalog.dart';
import 'package:forja/shared/engine/models/models.dart';
import 'package:forja/shared/engine/packs/settings/pack_connected_auth_spec.dart';
import 'package:forja/shared/engine/packs/settings/pack_connected_auth_service.dart';
import 'package:forja/shared/engine/packs/settings/pack_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PackConnectedAuthSpec', () {
    test('parses settings.auth without fields', () {
      final plugin = EnginePlugin.fromJson({
        'id': 'test-hub-auth',
        'name': 'Test Hub',
        'entry': 'x.js',
        'kind': 'catalog',
        'settings': {
          'addon': SettingsAddonId.connectedServices,
          'group': 'TestSvc',
          'order': 15,
          'extractPluginIds': ['test-provider'],
          'auth': {
            'kind': 'session',
            'label': 'TestSvc',
            'subtitle': 'Sign in',
          },
        },
      });
      final spec = PackConnectedAuthSpec.fromPlugin(plugin);
      expect(spec, isNotNull);
      expect(spec!.pluginId, 'test-hub-auth');
      expect(spec.label, 'TestSvc');
      expect(spec.order, 15);
      expect(spec.extractPluginIds, ['test-provider']);
      expect(spec.kind, 'session');
    });

    test('ignores auth outside connected_services', () {
      final plugin = EnginePlugin.fromJson({
        'id': 'test-hub-auth',
        'name': 'Test Hub',
        'entry': 'x.js',
        'kind': 'catalog',
        'settings': {
          'addon': 'live_sports',
          'auth': {'label': 'Nope'},
        },
      });
      expect(PackConnectedAuthSpec.fromPlugin(plugin), isNull);
    });

    test('listEnabled sorts by order', () {
      final a = EnginePlugin.fromJson({
        'id': 'a',
        'name': 'A',
        'entry': 'a.js',
        'kind': 'catalog',
        'enabled': true,
        'settings': {
          'addon': SettingsAddonId.connectedServices,
          'order': 30,
          'auth': {'label': 'Alpha'},
        },
      });
      final b = EnginePlugin.fromJson({
        'id': 'b',
        'name': 'B',
        'entry': 'b.js',
        'kind': 'catalog',
        'enabled': true,
        'settings': {
          'addon': SettingsAddonId.connectedServices,
          'order': 10,
          'auth': {'label': 'Beta'},
        },
      });
      final list = PackConnectedAuthSpec.listEnabled([a, b]);
      expect(list.map((e) => e.label).toList(), ['Beta', 'Alpha']);
    });

    test('listEnabled skips disabled plugins', () {
      final on = EnginePlugin.fromJson({
        'id': 'on',
        'name': 'On',
        'entry': 'on.js',
        'kind': 'catalog',
        'enabled': true,
        'settings': {
          'addon': SettingsAddonId.connectedServices,
          'auth': {'label': 'On'},
        },
      });
      final off = EnginePlugin.fromJson({
        'id': 'off',
        'name': 'Off',
        'entry': 'off.js',
        'kind': 'catalog',
        'enabled': false,
        'settings': {
          'addon': SettingsAddonId.connectedServices,
          'auth': {'label': 'Off'},
        },
      });
      final list = PackConnectedAuthSpec.listEnabled([on, off]);
      expect(list.map((e) => e.label).toList(), ['On']);
    });

    test('activePluginsFromPacks requires pack and plugin on', () {
      final authPlugin = EnginePlugin.fromJson({
        'id': 'auth-hub',
        'name': 'Auth Hub',
        'entry': 'x.js',
        'kind': 'catalog',
        'enabled': true,
        'settings': {
          'addon': SettingsAddonId.connectedServices,
          'auth': {'label': 'AuthSvc'},
        },
      });
      final disabledPack = EnginePack.fromJson(
        {
          'id': 'pack-off',
          'name': 'Off Pack',
          'version': '1.0.0',
          'enabled': false,
          'plugins': [authPlugin.toJson()],
        },
        sourceUrl: 'https://example.com/pack-off/manifest.json',
      );
      final enabledPack = EnginePack.fromJson(
        {
          'id': 'pack-on',
          'name': 'On Pack',
          'version': '1.0.0',
          'enabled': true,
          'plugins': [authPlugin.toJson()],
        },
        sourceUrl: 'https://example.com/pack-on/manifest.json',
      );
      expect(activePluginsFromPacks([disabledPack]), isEmpty);
      expect(
        activePluginsFromPacks([enabledPack]).map((p) => p.id).toList(),
        ['auth-hub'],
      );
      expect(
        PackConnectedAuthSpec.listEnabled(
          activePluginsFromPacks([disabledPack, enabledPack]),
        ).map((e) => e.label).toList(),
        ['AuthSvc'],
      );
    });
  });

  group('PackConnectedAuthStore', () {
    test('applyLoginResult stores secrets for extract overlay', () async {
      await PackConnectedAuthStore.applyLoginResult(
        pluginId: 'test-hub-auth',
        data: {
          'connected': true,
          'label': 'user@example.com',
          'secrets': {
            'sessionId': 'sess-1',
            'jwt': 'jwt-1',
          },
        },
      );
      expect(
        await PackConnectedAuthStore.profileLabel('test-hub-auth'),
        'user@example.com',
      );
      final overlay =
          await PackConnectedAuthStore.configOverlay('test-hub-auth');
      expect(overlay['sessionId'], 'sess-1');
      expect(overlay['jwt'], 'jwt-1');

      final hub = EnginePlugin.fromJson({
        'id': 'test-hub-auth',
        'name': 'Test Hub',
        'entry': 'x.js',
        'kind': 'catalog',
        'enabled': true,
        'settings': {
          'addon': SettingsAddonId.connectedServices,
          'extractPluginIds': ['test-provider'],
          'auth': {'label': 'TestSvc'},
        },
      });
      final extract = await PackConnectedAuthStore.loadExtractConfigOverlay(
        extractPluginId: 'test-provider',
        plugins: [hub],
      );
      expect(extract['sessionId'], 'sess-1');

      await PackConnectedAuthStore.clearSession('test-hub-auth');
      expect(await PackSettingsStore.getSecret('test-hub-auth', 'sessionId'), '');
    });
  });
}
