import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/engine/packs/settings/pack_green_play_config.dart';

void main() {
  group('PackGreenPlayConfig', () {
    test('hostFallback is engine-only', () {
      final c = PackGreenPlayConfig.hostFallback;
      expect(c.techAllowlist, [PackGreenPlayTechs.engine]);
      expect(c.techOrder, [PackGreenPlayTechs.engine]);
      expect(c.providers, isEmpty);
    });

    test('fromJson parses technologies and providers', () {
      final c = PackGreenPlayConfig.fromJson({
        'technologies': {
          'allowlist': ['engine', 'stremio'],
          'preferred': ['stremio'],
          'order': ['stremio', 'engine'],
        },
        'providers': {
          'engine': {
            'allowlist': ['alpha', 'beta'],
            'preferred': ['beta'],
            'order': ['beta', 'alpha'],
          },
        },
      });
      expect(c, isNotNull);
      expect(c!.techAllowlist, ['engine', 'stremio']);
      expect(c.techPreferred, ['stremio']);
      expect(c.techOrder, ['stremio', 'engine']);
      final eng = c.providerPrefs(PackGreenPlayTechs.engine);
      expect(eng.allowlist, ['alpha', 'beta']);
      expect(eng.preferred, ['beta']);
      expect(eng.order, ['beta', 'alpha']);
    });

    test('fromPlugin reads settings.greenPlay', () {
      final plugin = EnginePlugin.fromJson({
        'id': 'test-hub-a',
        'name': 'Test Hub',
        'kind': 'catalog',
        'entry': 'x.js',
        'settings': {
          'greenPlay': {
            'technologies': {
              'allowlist': ['engine', 'nuvio'],
              'preferred': ['engine'],
              'order': ['engine', 'nuvio'],
            },
            'providers': {
              'engine': {'allowlist': [], 'preferred': [], 'order': []},
            },
          },
        },
      });
      expect(PackGreenPlayConfig.isDeclared(plugin), isTrue);
      final c = PackGreenPlayConfig.fromPlugin(plugin);
      expect(c, isNotNull);
      expect(c!.techAllowlist, ['engine', 'nuvio']);
    });

    test('fromPlugin null when greenPlay omitted', () {
      final plugin = EnginePlugin.fromJson({
        'id': 'test-hub-b',
        'name': 'Test Hub B',
        'kind': 'catalog',
        'entry': 'x.js',
        'settings': {
          'fields': [
            {
              'id': 'episodeView',
              'type': 'select',
              'label': 'Episode list',
              'default': 'cards',
              'options': [
                {'id': 'cards', 'label': 'Cards'},
              ],
            },
          ],
        },
      });
      expect(PackGreenPlayConfig.isDeclared(plugin), isFalse);
      expect(PackGreenPlayConfig.fromPlugin(plugin), isNull);
    });

    test('orderProviderIds applies allowlist preferred and order', () {
      const c = PackGreenPlayConfig(
        providers: {
          PackGreenPlayTechs.engine: PackGreenPlayProviderPrefs(
            allowlist: ['a', 'b', 'c'],
            preferred: ['c'],
            order: ['b', 'a', 'c'],
          ),
        },
      );
      final ordered = c.orderProviderIds(
        tech: PackGreenPlayTechs.engine,
        available: ['a', 'b', 'c', 'd'],
      );
      expect(ordered, ['c', 'b', 'a']);
      expect(c.firstPreferredIn(PackGreenPlayTechs.engine, ordered), 'c');
    });

    test('empty allowlist means all available', () {
      const c = PackGreenPlayConfig(
        providers: {
          PackGreenPlayTechs.engine: PackGreenPlayProviderPrefs(
            preferred: ['b'],
            order: ['c', 'a', 'b'],
          ),
        },
      );
      final ordered = c.orderProviderIds(
        tech: PackGreenPlayTechs.engine,
        available: ['a', 'b', 'c'],
      );
      expect(ordered, ['b', 'c', 'a']);
    });

    test('round-trip toJson', () {
      final original = PackGreenPlayConfig.fromJson({
        'technologies': {
          'allowlist': ['engine', 'torrent'],
          'preferred': ['engine'],
          'order': ['engine', 'torrent'],
        },
        'providers': {
          'torrent': {
            'allowlist': ['yts'],
            'preferred': ['yts'],
            'order': ['yts'],
          },
        },
      })!;
      final again = PackGreenPlayConfig.fromJson(original.toJson());
      expect(again!.techAllowlist, original.techAllowlist);
      expect(again.techPreferred, original.techPreferred);
      expect(
        again.providerPrefs(PackGreenPlayTechs.torrent).allowlist,
        ['yts'],
      );
    });
  });
}
