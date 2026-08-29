import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/catalog/catalog.dart';
import 'package:forja/shared/engine/models.dart';
import 'package:forja/shared/engine/plugin_registry.dart';

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
      expect(
        PluginRegistry.officialPackIds,
        containsAll([
          'forjahq-home',
          'forjahq-anime',
          'forjahq-asian-drama',
          'forjahq-arabic',
        ]),
      );

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
      expect(PluginNavRegistry.builtInHubPluginIds['anime'], 'anilist');

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

    test('hub manifest urls map to home / anime / asian_drama / arabic slots', () {
      expect(PluginRegistry.requiredOfficialPackCount, 6);
      expect(
        PluginRegistry.forjaHqSlot(
          'https://x/plugins/hubs/home/manifest.json',
        ),
        'home',
      );
      expect(
        PluginRegistry.forjaHqSlot(
          'https://x/plugins/hubs/anime/manifest.json',
        ),
        'anime',
      );
      expect(
        PluginRegistry.forjaHqSlot(
          '/Users/me/Forja/plugins/hubs/asian_drama/manifest.json',
        ),
        'asian_drama',
      );
      expect(
        PluginRegistry.forjaHqSlot('https://x/plugins/hubs/manifest.json'),
        'home',
      );
      expect(PluginRegistry.officialSlotOrder, contains('asian_drama'));
      expect(
        PluginRegistry.forjaHqSlot(
          'https://x/plugins/hubs/arabic/manifest.json',
        ),
        'arabic',
      );
      expect(
        PluginRegistry.hubSlotIds,
        containsAll(['home', 'anime', 'asian_drama', 'arabic']),
      );
    });

    test('plugin json round-trips the catalog fields', () {
      final plugin = EnginePlugin.fromJson({
        'id': 'kisskh-hub',
        'name': 'Asian Drama',
        'entry': 'kisskh.js',
        'kind': 'catalog',
        'protocol': 1,
        'kit': 1,
        'capabilities': ['nav', 'rail'],
        'nav': {'tabId': 'asian_drama', 'label': 'Asian Drama', 'order': 30},
        'enrich': 'enrich-tmdb',
      });
      final again = EnginePlugin.fromJson(plugin.toJson());
      expect(again.isHubCatalog, isTrue);
      expect(again.capabilities, ['nav', 'rail']);
      expect(again.nav!['tabId'], 'asian_drama');
      expect(again.enrich, 'enrich-tmdb');
      expect(again.copyWith(enabled: false).enrich, 'enrich-tmdb');
    });
  });
}
