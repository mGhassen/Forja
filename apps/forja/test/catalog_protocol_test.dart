import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/catalog/catalog.dart';
import 'package:forja/shared/catalog/kit/chrome/catalog_chrome_filters.dart';
import 'package:forja/shared/catalog/kit/chrome/catalog_pack_filters.dart';
import 'package:forja/shared/catalog/kit/chrome/catalog_vertical_filters.dart';
import 'package:forja/shared/engine/models.dart';
import 'package:forja/shared/engine/plugin_registry.dart';
import 'package:forja/shell/shell_bus.dart';

/// `plugins/hubs/fixtures/<name>.json` — test cwd is `apps/forja`.
dynamic loadHubFixture(String name) {
  final file = File('../../plugins/hubs/fixtures/$name.json');
  expect(file.existsSync(), isTrue, reason: 'missing fixture ${file.path}');
  return jsonDecode(file.readAsStringSync());
}

/// `plugins/hubs/<pack>/manifest.json` — test cwd is `apps/forja`.
Map<String, dynamic> loadHubPackManifest(String packDir) {
  final file = File('../../plugins/hubs/$packDir/manifest.json');
  expect(file.existsSync(), isTrue, reason: 'missing ${file.path}');
  return Map<String, dynamic>.from(
    jsonDecode(file.readAsStringSync()) as Map,
  );
}

List<EnginePlugin> loadAllHubPlugins() {
  final out = <EnginePlugin>[];
  for (final dir in ['home', 'anime', 'asian_drama', 'arabic']) {
    final pack = EnginePack.fromJson(
      loadHubPackManifest(dir),
      sourceUrl: 'file:///plugins/hubs/$dir/manifest.json',
    );
    out.addAll(pack.plugins);
  }
  return out;
}

void main() {
  group('envelope parsing', () {
    test('reads the envelope out of a single-element list', () {
      final envelope = parseEnvelope(loadHubFixture('anilist_layout'));
      expect(envelope, isNotNull);
      expect(envelope!.ok, isTrue);
      expect(envelope.action, 'layout');
      expect(envelope.kit, hostKitVersion);
      expect(envelope.protocol, hostProtocolVersion);
      expect(envelope.cache.maxAge, const Duration(seconds: 3600));
      expect(envelope.cache.swr, const Duration(seconds: 86400));
    });

    test('reads a bare envelope map', () {
      final envelope = parseEnvelope({'ok': true, 'action': 'rail'});
      expect(envelope?.action, 'rail');
    });

    test('returns null for non-protocol payloads', () {
      expect(parseEnvelope([{'url': 'https://x'}]), isNull);
      expect(parseEnvelope('nope'), isNull);
      expect(parseEnvelope(null), isNull);
    });

    test('flags a plugin that needs a newer host kit', () {
      final envelope = parseEnvelope(loadHubFixture('unsupported_kit'));
      expect(envelope!.isUnsupportedKit, isTrue);
    });

    test('maps error codes and retryability', () {
      final envelope = parseEnvelope(loadHubFixture('tmdb_auth_required'));
      expect(envelope!.ok, isFalse);
      expect(envelope.error!.code, CatalogErrorCode.authRequired);
      expect(envelope.error!.code.isAuth, isTrue);
      expect(envelope.error!.isRetryable, isFalse);
      expect(
        CatalogErrorCode.tryParse('RATE_LIMIT'),
        CatalogErrorCode.rateLimit,
      );
      expect(
        CatalogErrorCode.tryParse('rate_limit'),
        CatalogErrorCode.rateLimit,
        reason: 'casing is normalized',
      );
      expect(CatalogErrorCode.tryParse('nope'), isNull);
      expect(CatalogErrorCode.upstream.retryableByDefault, isTrue);
      expect(CatalogErrorCode.notFound.retryableByDefault, isFalse);
    });
  });

  group('meta items', () {
    test('parses ids, rating and badge', () {
      final envelope = parseEnvelope(loadHubFixture('anilist_rail'))!;
      final items = envelope.items;
      expect(items, hasLength(2));
      final one = items.first;
      expect(one.name, 'ONE PIECE');
      expect(one.type, 'anime');
      expect(one.idNamespace, 'anilist');
      expect(one.numericId('anilist'), 21);
      expect(one.numericId('mal'), 21);
      expect(one.numericId('tmdb'), isNull);
      expect(one.rating, 8.8);
      expect(one.badge, 'TV');
      expect(one.genres, contains('Adventure'));
    });

    test('resolves namespaced tmdb ids from the id string', () {
      final item = CatalogMetaItem.fromJson({
        'id': 'tmdb:movie:603',
        'type': 'movie',
        'name': 'The Matrix',
      });
      expect(item.numericId('tmdb'), 603);
    });

    test('kisskh rows carry both kisskh and tmdb ids', () {
      final item = parseEnvelope(loadHubFixture('kisskh_rail'))!.items.single;
      expect(item.numericId('kisskh'), 10633);
      expect(item.numericId('tmdb'), 215720);
    });

    test('round-trips through json', () {
      final item = parseEnvelope(loadHubFixture('anilist_rail'))!.items.first;
      final again = CatalogMetaItem.fromJson(item.toJson());
      expect(again.toJson(), item.toJson());
    });
  });

  group('layout validation', () {
    test('accepts the shipped anilist layout', () {
      final envelope = parseEnvelope(loadHubFixture('anilist_layout'))!;
      expect(validateLayoutData(envelope.data), isNull);
    });

    test('rejects missing pages / widgets / type', () {
      expect(validateLayoutData(null), isNotNull);
      expect(validateLayoutData({}), isNotNull);
      expect(validateLayoutData({'pages': {}}), isNotNull);
      expect(validateLayoutData({'pages': {'home': {}}}), isNotNull);
      expect(
        validateLayoutData({
          'pages': {
            'home': {'widgets': [{'id': 'x'}]},
          },
        }),
        isNotNull,
      );
    });
  });

  group('filter AST', () {
    test('drops empty nodes and unwraps single nodes', () {
      expect(CatalogFilterAst.andFilters([null, null]), isNull);
      expect(
        CatalogFilterAst.andFilters([CatalogFilterAst.eq('genre', 'Action')]),
        {'field': 'genre', 'op': 'eq', 'value': 'Action'},
      );
    });

    test('groups multiple leaves under and', () {
      final ast = CatalogFilterAst.andFilters([
        CatalogFilterAst.inList('genre', ['Action']),
        CatalogFilterAst.eq('year', 2026),
      ]);
      expect(ast!['op'], 'and');
      expect(ast['nodes'], hasLength(2));
    });

    test('parse rejects leaves without a field or value', () {
      expect(CatalogFilterAst.parse({'op': 'eq', 'value': 1}), isNull);
      expect(CatalogFilterAst.parse({'field': 'genre'}), isNull);
      expect(CatalogFilterAst.parse({'op': 'and', 'nodes': []}), isNull);
    });

    test('merges chrome selections into params', () {
      final params = catalogParamsWithFilters(
        {'rail': 'popular'},
        filters: [catalogFilterFromSelection(field: 'genre', value: ['28'])],
        sort: 'popularity.desc',
        limit: 20,
      );
      expect(params['rail'], 'popular');
      expect(params['sort'], 'popularity.desc');
      expect(params['limit'], 20);
      expect(params['filter'], {
        'field': 'genre',
        'op': 'in',
        'value': ['28'],
      });
    });

    test('empty selections add no filter', () {
      expect(catalogFilterFromSelection(field: 'genre', value: null), isNull);
      expect(catalogFilterFromSelection(field: 'genre', value: ''), isNull);
      expect(
        catalogFilterFromSelection(field: 'genre', value: const <String>[]),
        isNull,
      );
      expect(
        catalogParamsWithFilters({'rail': 'x'}).containsKey('filter'),
        isFalse,
      );
    });

    test('mood options fall back to their genre', () {
      expect(catalogMoodFilter({'id': 'a', 'genre': 'Action'}), {
        'field': 'genre',
        'op': 'in',
        'value': ['Action'],
      });
      expect(catalogMoodFilter({'id': 'a'}), isNull);
    });
  });

  group('chrome filter epoch', () {
    test('pack filters revision bump does not change epoch', () {
      const tabId = 'anime';
      ShellBus.hubCategoryFor(tabId).value = null;
      ShellBus.hubSelectedCategoryIdFor(tabId).value = null;
      CatalogVerticalFiltersRegistry.selectedIdFor(tabId).value = null;
      final before = catalogChromeFilterEpoch(tabId);
      CatalogPackFiltersRegistry.revision.value++;
      expect(catalogChromeFilterEpoch(tabId), before);
    });

    test('category selection changes epoch', () {
      const tabId = 'anime';
      ShellBus.hubCategoryFor(tabId).value = null;
      ShellBus.hubSelectedCategoryIdFor(tabId).value = null;
      CatalogVerticalFiltersRegistry.selectedIdFor(tabId).value = null;
      final before = catalogChromeFilterEpoch(tabId);
      ShellBus.hubCategoryFor(tabId).value = ShellHomeCategory.films;
      expect(catalogChromeFilterEpoch(tabId), isNot(before));
      ShellBus.hubCategoryFor(tabId).value = null;
    });
  });

  group('cache', () {
    setUp(CatalogCache.instance.wipeAll);

    test('key is stable across param order', () {
      final a = CatalogCache.keyFor(
        pluginId: 'anilist',
        action: 'rail',
        params: {'rail': 'trending', 'limit': 20},
      );
      final b = CatalogCache.keyFor(
        pluginId: 'anilist',
        action: 'rail',
        params: {'limit': 20, 'rail': 'trending'},
      );
      expect(a, b);
      expect(a, startsWith('anilist|rail|'));
    });

    test('auth subject and params change the key', () {
      final base = CatalogCache.keyFor(pluginId: 'p', action: 'rail');
      expect(
        CatalogCache.keyFor(pluginId: 'p', action: 'rail', authSubject: 'u1'),
        isNot(base),
      );
      expect(
        CatalogCache.keyFor(pluginId: 'p', action: 'rail', params: {'a': 1}),
        isNot(base),
      );
    });

    test('honours maxAge then the swr window', () {
      const key = 'k';
      CatalogCache.instance.put(
        key: key,
        pluginId: 'anilist',
        data: const {'items': []},
        hints: const CatalogCacheHints(
          maxAge: Duration(seconds: 1),
          swr: Duration(minutes: 5),
        ),
      );
      final entry = CatalogCache.instance.get(key)!;
      expect(entry.isFresh, isTrue);
      expect(entry.isExpired, isFalse);

      final stale = entry.copyWithStoredAt(
        DateTime.now().subtract(const Duration(seconds: 30)),
      );
      expect(stale.isFresh, isFalse);
      expect(stale.isRevalidatable, isTrue);

      final dead = entry.copyWithStoredAt(
        DateTime.now().subtract(const Duration(hours: 2)),
      );
      expect(dead.isExpired, isTrue);
    });

    test('wipePlugin drops only that plugin', () {
      CatalogCache.instance.put(
        key: 'a',
        pluginId: 'anilist',
        data: const {},
      );
      CatalogCache.instance.put(key: 'b', pluginId: 'kisskh-hub', data: const {});
      CatalogCache.instance.wipePlugin('anilist');
      expect(CatalogCache.instance.get('a'), isNull);
      expect(CatalogCache.instance.get('b'), isNotNull);
    });

    test('pack version change wipes everything', () {
      CatalogCache.instance.syncHubPackVersion('forjahq-home', '1.0.0');
      CatalogCache.instance.put(key: 'a', pluginId: 'anilist', data: const {});
      CatalogCache.instance.syncHubPackVersion('forjahq-home', '1.0.0');
      expect(CatalogCache.instance.get('a'), isNotNull);
      CatalogCache.instance.syncHubPackVersion('forjahq-home', '1.0.1');
      expect(CatalogCache.instance.get('a'), isNull);
    });
  });

  group('enrich cache skip', () {
    test('details skips when kit marker set', () {
      expect(
        CatalogRuntime.envelopeAlreadyEnriched(
          'details',
          {
            'meta': {
              'id': 'anilist:1',
              '_hubTmdbEnriched': true,
            },
          },
          const {},
        ),
        isTrue,
      );
    });

    test('details does not skip on legacy tmdb backdrop alone', () {
      expect(
        CatalogRuntime.envelopeAlreadyEnriched(
          'details',
          {
            'meta': {
              'ids': {'tmdb': '603'},
              'background':
                  'https://image.tmdb.org/t/p/w1280/abc.jpg',
            },
          },
          const {},
        ),
        isFalse,
      );
    });

    test('spotlight rail skips on legacy tmdb backdrop', () {
      expect(
        CatalogRuntime.envelopeAlreadyEnriched(
          'rail',
          {
            'items': [
              {
                'ids': {'tmdb': '603'},
                'background':
                    'https://image.tmdb.org/t/p/w1280/abc.jpg',
                'id': 'kisskh:1',
              },
            ],
          },
          const {'rail': 'spotlight'},
        ),
        isTrue,
      );
    });

    test('details does not skip bare ids.tmdb', () {
      expect(
        CatalogRuntime.envelopeAlreadyEnriched(
          'details',
          {
            'meta': {
              'ids': {'tmdb': '603'},
              'background': 'https://cdn.anilist.co/img.jpg',
            },
          },
          const {},
        ),
        isFalse,
      );
    });

    test('spotlight rail skips when head items enriched', () {
      expect(
        CatalogRuntime.envelopeAlreadyEnriched(
          'rail',
          {
            'items': [
              {
                '_hubTmdbEnriched': true,
                'id': 'a:1',
              },
            ],
          },
          const {'rail': 'spotlight'},
        ),
        isTrue,
      );
    });

    test('non-spotlight rail never skips', () {
      expect(
        CatalogRuntime.envelopeAlreadyEnriched(
          'rail',
          {
            'items': [
              {'_hubTmdbEnriched': true, 'id': 'a:1'},
            ],
          },
          const {'rail': 'trending'},
        ),
        isFalse,
      );
    });
  });

  group('deep links', () {
    test('parses plugin, action and id', () {
      final link = CatalogDeepLink.parse(
        'forja://catalog/anilist/details?id=anilist%3A21&from=home',
      )!;
      expect(link.pluginId, 'anilist');
      expect(link.action, 'details');
      expect(link.id, 'anilist:21');
      expect(link.params['from'], 'home');
    });

    test('defaults the action to details', () {
      expect(CatalogDeepLink.parse('forja://catalog/tmdb')?.action, 'details');
    });

    test('rejects other schemes and hosts', () {
      expect(CatalogDeepLink.parse('https://catalog/anilist/details'), isNull);
      expect(CatalogDeepLink.parse('forja://player/anilist'), isNull);
      expect(CatalogDeepLink.parse('forja://catalog'), isNull);
    });

    test('round-trips through a uri', () {
      const link = CatalogDeepLink(
        pluginId: 'kisskh-hub',
        action: 'details',
        id: 'kisskh:10633',
      );
      expect(CatalogDeepLink.parse(link.toString())!.id, 'kisskh:10633');
    });
  });

  group('hub packs', () {
    test('home / anime / asian_drama / arabic manifests declare catalog plugins', () {
      final home = EnginePack.fromJson(
        loadHubPackManifest('home'),
        sourceUrl: 'file:///plugins/hubs/home/manifest.json',
      );
      final anime = EnginePack.fromJson(
        loadHubPackManifest('anime'),
        sourceUrl: 'file:///plugins/hubs/anime/manifest.json',
      );
      final drama = EnginePack.fromJson(
        loadHubPackManifest('asian_drama'),
        sourceUrl: 'file:///plugins/hubs/asian_drama/manifest.json',
      );
      final arabic = EnginePack.fromJson(
        loadHubPackManifest('arabic'),
        sourceUrl: 'file:///plugins/hubs/arabic/manifest.json',
      );
      expect(home.packId, 'forjahq-home');
      expect(anime.packId, 'forjahq-anime');
      expect(drama.packId, 'forjahq-asian-drama');
      expect(arabic.packId, 'forjahq-arabic');
      expect(home.plugins.map((p) => p.id), ['tmdb']);
      expect(arabic.plugins.map((p) => p.id), ['arabic-hub']);

      final byId = {
        for (final p in [
          ...home.plugins,
          ...anime.plugins,
          ...drama.plugins,
          ...arabic.plugins,
        ])
          p.id: p,
      };
      expect(
        byId.keys,
        containsAll([
          'tmdb',
          'anilist',
          'anime-enrich-tmdb',
          'kisskh-hub',
          'enrich-tmdb',
          'arabic-hub',
        ]),
      );
      expect(byId['anilist']!.enrich, 'anime-enrich-tmdb');
      expect(byId['kisskh-hub']!.enrich, 'enrich-tmdb');
      expect(byId['anime-enrich-tmdb']!.hasCapability('enrich'), isTrue);
      expect(byId['anime-enrich-tmdb']!.hasCapability('nav'), isFalse);
      expect(byId['enrich-tmdb']!.hasCapability('enrich'), isTrue);
      expect(byId['enrich-tmdb']!.hasCapability('nav'), isFalse);

      for (final plugin in byId.values) {
        expect(plugin.isHubCatalog, isTrue, reason: plugin.id);
        expect(plugin.isExtractable, isFalse, reason: plugin.id);
        expect(plugin.needsScript, isTrue, reason: plugin.id);
        expect(plugin.kit, hostKitVersion, reason: plugin.id);
        expect(plugin.protocol, hostProtocolVersion, reason: plugin.id);
        expect(plugin.prelude, '_kit.js', reason: plugin.id);
        if (plugin.hasCapability('enrich') && !plugin.hasCapability('nav')) {
          continue;
        }
        expect(plugin.hasCapability('nav'), isTrue, reason: plugin.id);
      }

      expect(File('../../plugins/hubs/home/tmdb.js').existsSync(), isTrue);
      expect(File('../../plugins/hubs/anime/anilist.js').existsSync(), isTrue);
      expect(
        File('../../plugins/hubs/anime/enrich_tmdb.js').existsSync(),
        isTrue,
      );
      expect(
        File('../../plugins/hubs/asian_drama/kisskh.js').existsSync(),
        isTrue,
      );
      expect(
        File('../../plugins/hubs/asian_drama/enrich_tmdb.js').existsSync(),
        isTrue,
      );
    });

    test('nav specs map plugins onto hub tabs', () {
      final specs = [
        for (final p in loadAllHubPlugins())
          if (p.nav != null)
            CatalogNavSpec.fromPluginNav(
              p.nav,
              pluginId: p.id,
              fallbackLabel: p.name,
            )!,
      ];
      final byTab = {for (final s in specs) s.tabId: s};
      expect(byTab['home']!.pluginId, 'tmdb');
      expect(byTab['anime']!.pluginId, 'anilist');
      expect(byTab['asian_drama']!.pluginId, 'kisskh-hub');
      expect(byTab['arabic']!.pluginId, 'arabic-hub');
      expect(byTab['arabic']!.defaultEnabled, isFalse);
      expect(byTab['home']!.accent, '#1CE783');
      expect(byTab['home']!.order, 10);

      for (final tab in byTab.keys) {
        expect(PluginNavRegistry.isHubTab(tab), isTrue, reason: tab);
        expect(
          PluginNavRegistry.coreShellNavIds.contains(tab),
          isFalse,
          reason: tab,
        );
      }
      expect(PluginNavRegistry.isHubTab('settings'), isFalse);
      expect(PluginNavRegistry.seedHubTabIds, contains('anime'));

      PluginNavRegistry.seedBuiltIns();
      expect(PluginNavRegistry.builders.containsKey('home'), isTrue);
      expect(PluginNavRegistry.destinations['home']!.label, 'Home');
      expect(PluginNavRegistry.accents['anime'], isNotNull);
    });

    test('nav icons use forja://asset ids, not Flutter assets/ paths', () {
      final specs = [
        for (final p in loadAllHubPlugins())
          if (p.nav != null)
            CatalogNavSpec.fromPluginNav(
              p.nav,
              pluginId: p.id,
              fallbackLabel: p.name,
            )!,
      ];
      final byTab = {for (final s in specs) s.tabId: s};

      expect(byTab['home']!.icon, ForjaHostAssets.uriNavHome);
      expect(byTab['anime']!.icon, ForjaHostAssets.uriNavAnime);
      expect(byTab['asian_drama']!.icon, ForjaHostAssets.uriNavAsianDrama);

      for (final s in specs) {
        final icon = s.icon;
        if (icon == null || icon.isEmpty) continue;
        expect(
          icon.startsWith('assets/'),
          isFalse,
          reason: '${s.tabId} must not leak Flutter asset paths',
        );
        expect(
          ForjaHostAssets.isKnown(icon),
          isTrue,
          reason: '${s.tabId} icon $icon must be in ForjaHostAssets.catalog',
        );
        expect(
          ForjaHostAssets.resolveFlutterPath(icon),
          isNotNull,
        );
      }

      expect(
        ForjaHostAssets.resolveFlutterPath('assets/images/nav/home.png'),
        isNull,
      );
      expect(
        ForjaHostAssets.resolveFlutterPath(ForjaHostAssets.uriNavHome),
        ForjaHostAssets.flutterNavHome,
      );
      expect(ForjaHostAssets.ids, contains('nav/home'));
    });

    test('forjaHqSlot extracts arbitrary hub path segment from manifest url', () {
      expect(
        PluginRegistry.forjaHqSlot(
          'https://x/plugins/hubs/my_custom_hub/manifest.json',
        ),
        'my_custom_hub',
      );
      expect(
        PluginRegistry.forjaHqSlot(
          '/Users/me/Forja/plugins/hubs/another_slot/manifest.json',
        ),
        'another_slot',
      );
      expect(
        PluginRegistry.forjaHqSlot('https://x/plugins/hubs/manifest.json'),
        'home',
      );
      expect(PluginRegistry.hubSlotLabel('my_custom_hub'), 'My Custom Hub');
    });

    test('plugin json round-trips the catalog fields', () {
      final plugin = EnginePlugin.fromJson({
        'id': 'hub-plugin-test',
        'name': 'Test Hub',
        'entry': 'hub.js',
        'kind': 'catalog',
        'protocol': 1,
        'kit': 1,
        'capabilities': ['nav', 'rail'],
        'nav': {'tabId': 'custom_tab', 'label': 'Custom Tab', 'order': 30},
        'enrich': 'enrich-companion-test',
      });
      final again = EnginePlugin.fromJson(plugin.toJson());
      expect(again.isHubCatalog, isTrue);
      expect(again.capabilities, ['nav', 'rail']);
      expect(again.nav!['tabId'], 'custom_tab');
      expect(again.enrich, 'enrich-companion-test');
      expect(again.copyWith(enabled: false).enrich, 'enrich-companion-test');
    });
  });
}
