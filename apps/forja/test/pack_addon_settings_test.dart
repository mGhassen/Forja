import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/settings/addons/settings_addon_catalog.dart';
import 'package:forja/shared/engine/models/models.dart';
import 'package:forja/shared/host/packs/services/pack_addon_settings_spec.dart';
import 'package:forja/shared/host/packs/services/pack_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('EnginePlugin.settings', () {
    test('round-trips settings block without host addon id', () {
      final plugin = EnginePlugin.fromJson({
        'id': 'test-hub-a',
        'name': 'Hub A',
        'entry': 'a.js',
        'kind': 'catalog',
        'capabilities': ['nav', 'settings'],
        'settings': {
          'group': 'Hub A',
          'order': 5,
          'fields': [
            {
              'id': 'flag',
              'type': 'toggle',
              'label': 'Flag',
              'default': true,
            },
          ],
        },
      });
      expect(plugin.settings, isNotNull);
      expect(plugin.hasCapability('settings'), isTrue);
      final again = EnginePlugin.fromJson(plugin.toJson());
      expect(again.settings?['addon'], isNull);
      expect((again.settings?['fields'] as List).length, 1);
    });
  });

  group('PackAddonSettingsSpec', () {
    test('parses toggle select text from synthetic plugin', () {
      final plugin = EnginePlugin.fromJson({
        'id': 'test-provider-a',
        'name': 'Provider A',
        'entry': 'a.js',
        'kind': 'http',
        'settings': {
          'addon': 'torrent',
          'order': 10,
          'fields': [
            {
              'id': 'on',
              'type': 'toggle',
              'label': 'On',
              'default': false,
            },
            {
              'id': 'mode',
              'type': 'select',
              'label': 'Mode',
              'default': 'fast',
              'options': [
                {'id': 'fast', 'label': 'Fast'},
                {'id': 'safe', 'label': 'Safe'},
              ],
            },
            {
              'id': 'note',
              'type': 'text',
              'label': 'Note',
              'default': 'hi',
            },
          ],
        },
      });
      final spec = PackAddonSettingsSpec.fromPlugin(plugin);
      expect(spec, isNotNull);
      expect(spec!.addonId, 'torrent');
      expect(spec.fields.length, 3);
      expect(spec.fields[0].type, PackAddonSettingsFieldType.toggle);
      expect(spec.fields[1].type, PackAddonSettingsFieldType.select);
      expect(spec.fields[1].options.map((o) => o.id), ['fast', 'safe']);
      expect(spec.fields[2].type, PackAddonSettingsFieldType.text);
    });

    test('parses fields when addon id omitted', () {
      final plugin = EnginePlugin.fromJson({
        'id': 'hub-no-addon',
        'name': 'Hub',
        'entry': 'h.js',
        'kind': 'catalog',
        'settings': {
          'group': 'Setup',
          'fields': [
            {'id': 'x', 'type': 'toggle', 'label': 'X', 'default': false},
          ],
        },
      });
      final spec = PackAddonSettingsSpec.fromPlugin(plugin);
      expect(spec, isNotNull);
      expect(spec!.addonId, isEmpty);
      expect(spec.fields.single.id, 'x');
    });

    test('listForAddon filters enabled plugins by addon id', () {
      final a = EnginePlugin.fromJson({
        'id': 'hub-a',
        'name': 'A',
        'entry': 'a.js',
        'kind': 'catalog',
        'enabled': true,
        'settings': {
          'addon': 'torrent',
          'order': 20,
          'fields': [
            {'id': 'x', 'type': 'toggle', 'label': 'X', 'default': false},
          ],
        },
      });
      final b = EnginePlugin.fromJson({
        'id': 'hub-b',
        'name': 'B',
        'entry': 'b.js',
        'kind': 'catalog',
        'enabled': false,
        'settings': {
          'addon': 'torrent',
          'order': 10,
          'fields': [
            {'id': 'y', 'type': 'toggle', 'label': 'Y', 'default': true},
          ],
        },
      });
      final c = EnginePlugin.fromJson({
        'id': 'hub-c',
        'name': 'C',
        'entry': 'c.js',
        'kind': 'catalog',
        'enabled': true,
        'settings': {
          'addon': 'iptv',
          'order': 1,
          'fields': [
            {'id': 'z', 'type': 'toggle', 'label': 'Z', 'default': false},
          ],
        },
      });
      final list = PackAddonSettingsSpec.listForAddon(
        [a, b, c],
        addonId: 'torrent',
      );
      expect(list.map((s) => s.pluginId), ['hub-a']);
    });

    test('listForPlugins returns specs without host addon filter', () {
      final a = EnginePlugin.fromJson({
        'id': 'hub-a',
        'name': 'A',
        'entry': 'a.js',
        'kind': 'catalog',
        'enabled': false,
        'settings': {
          'order': 20,
          'fields': [
            {'id': 'x', 'type': 'toggle', 'label': 'X', 'default': false},
          ],
        },
      });
      final list = PackAddonSettingsSpec.listForPlugins([a]);
      expect(list.map((s) => s.pluginId), ['hub-a']);
    });

    test('listContributingEnabled requires settings.addon', () {
      final withAddon = EnginePlugin.fromJson({
        'id': 'hub-a',
        'name': 'A',
        'entry': 'a.js',
        'kind': 'catalog',
        'enabled': true,
        'settings': {
          'addon': 'live_sports',
          'fields': [
            {'id': 'x', 'type': 'toggle', 'label': 'X', 'default': false},
          ],
        },
      });
      final noAddon = EnginePlugin.fromJson({
        'id': 'hub-b',
        'name': 'B',
        'entry': 'b.js',
        'kind': 'catalog',
        'enabled': true,
        'settings': {
          'fields': [
            {'id': 'y', 'type': 'toggle', 'label': 'Y', 'default': false},
          ],
        },
      });
      final list = PackAddonSettingsSpec.listContributingEnabled([
        withAddon,
        noAddon,
      ]);
      expect(list.map((s) => s.pluginId), ['hub-a']);
    });

    test('packContributedAddonMetas invents non-host addon rows', () {
      final hub = EnginePlugin.fromJson({
        'id': 'hub-live',
        'name': 'Live Sports Hub',
        'entry': 'h.js',
        'kind': 'catalog',
        'enabled': true,
        'nav': {'tabId': 'live_sports', 'label': 'Live Sports'},
        'settings': {
          'addon': 'live_sports',
          'fields': [
            {'id': 'x', 'type': 'toggle', 'label': 'X', 'default': false},
          ],
        },
      });
      final intoHost = EnginePlugin.fromJson({
        'id': 'hub-iptv',
        'name': 'Iptv Extra',
        'entry': 'i.js',
        'kind': 'catalog',
        'enabled': true,
        'settings': {
          'addon': 'iptv',
          'fields': [
            {'id': 'z', 'type': 'toggle', 'label': 'Z', 'default': false},
          ],
        },
      });
      final metas = packContributedAddonMetas([hub, intoHost]);
      expect(metas.length, 1);
      expect(metas.single.id, 'live_sports');
      expect(metas.single.title, 'Live Sports');
      expect(metas.single.packContributed, isTrue);
      expect(metas.single.hasToggle, isFalse);
    });

    test('rejects select without options', () {
      final plugin = EnginePlugin.fromJson({
        'id': 'bad',
        'name': 'Bad',
        'entry': 'b.js',
        'settings': {
          'addon': 'iptv',
          'fields': [
            {'id': 'mode', 'type': 'select', 'label': 'Mode'},
          ],
        },
      });
      expect(PackAddonSettingsSpec.fromPlugin(plugin), isNull);
    });

    test('parses multi_select with options and default list', () {
      final plugin = EnginePlugin.fromJson({
        'id': 'hub-multi',
        'name': 'Hub Multi',
        'entry': 'm.js',
        'kind': 'catalog',
        'settings': {
          'fields': [
            {
              'id': 'leagues',
              'type': 'multi_select',
              'label': 'Leagues',
              'default': ['A', 'B'],
              'options': [
                {'id': 'A', 'label': 'Alpha'},
                {'id': 'B', 'label': 'Beta'},
                {'id': 'C', 'label': 'Gamma'},
              ],
            },
          ],
        },
      });
      final spec = PackAddonSettingsSpec.fromPlugin(plugin);
      expect(spec, isNotNull);
      expect(spec!.fields.single.type, PackAddonSettingsFieldType.multiSelect);
      expect(spec.fields.single.defaultStringList, ['A', 'B']);
      expect(spec.fields.single.options.map((o) => o.id), ['A', 'B', 'C']);
    });
  });

  group('PackSettingsStore', () {
    test('bool and string persist with defaults', () async {
      expect(
        await PackSettingsStore.getBool(
          'p1',
          'flag',
          defaultValue: true,
        ),
        isTrue,
      );
      await PackSettingsStore.setBool('p1', 'flag', false);
      expect(
        await PackSettingsStore.getBool(
          'p1',
          'flag',
          defaultValue: true,
        ),
        isFalse,
      );

      expect(
        await PackSettingsStore.getString(
          'p1',
          'name',
          defaultValue: 'x',
        ),
        'x',
      );
      await PackSettingsStore.setString('p1', 'name', 'y');
      expect(
        await PackSettingsStore.getString(
          'p1',
          'name',
          defaultValue: 'x',
        ),
        'y',
      );
    });

    test('migrateBoolIfAbsent copies once', () async {
      final first = await PackSettingsStore.migrateBoolIfAbsent(
        'p2',
        'legacy',
        true,
      );
      final second = await PackSettingsStore.migrateBoolIfAbsent(
        'p2',
        'legacy',
        false,
      );
      expect(first, isTrue);
      expect(second, isFalse);
      expect(
        await PackSettingsStore.getBool(
          'p2',
          'legacy',
          defaultValue: false,
        ),
        isTrue,
      );
    });

    test('string list empty selection is not default', () async {
      expect(
        await PackSettingsStore.getStringList(
          'p3',
          'leagues',
          defaultValue: const ['NBA'],
        ),
        ['NBA'],
      );
      await PackSettingsStore.setStringList('p3', 'leagues', const []);
      expect(
        await PackSettingsStore.getStringList(
          'p3',
          'leagues',
          defaultValue: const ['NBA'],
        ),
        isEmpty,
      );
      await PackSettingsStore.setStringList('p3', 'leagues', const ['NBA', 'NFL']);
      expect(
        await PackSettingsStore.getStringList(
          'p3',
          'leagues',
          defaultValue: const [],
        ),
        ['NBA', 'NFL'],
      );
    });
  });
}
