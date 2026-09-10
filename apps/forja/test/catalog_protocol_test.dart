import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/foundation/foundation.dart';
import 'package:forja/shared/foundation/components/chrome/pack_filters.dart';
import 'package:forja/shared/engine/models/models.dart';
import 'package:forja/shared/engine/packs/forja_packs_root.dart';
import 'package:forja/shared/engine/packs/registry/plugin_registry.dart';
import 'package:forja/shared/engine/packs/registry/plugin_script_disk_store.dart';
import 'package:forja/shell/nav/nav_destination.dart';
import 'package:forja/shell/bus/shell_bus.dart';

String? _packsRoot() => ForjaPacksRoot.resolve(requireDebug: false);

/// `sdk/fixtures/<name>.json` under forja-packs.
dynamic loadHubFixture(String name) {
  final root = _packsRoot();
  expect(root, isNotNull, reason: 'forja-packs not found');
  final file = File('$root/sdk/fixtures/$name.json');
  expect(file.existsSync(), isTrue, reason: 'missing fixture ${file.path}');
  return jsonDecode(file.readAsStringSync());
}

/// `hubs/<pack>/manifest.json` under forja-packs.
Map<String, dynamic> loadHubPackManifest(String packDir) {
  final root = _packsRoot();
  expect(root, isNotNull, reason: 'forja-packs not found');
  final file = File('$root/hubs/$packDir/manifest.json');
  expect(file.existsSync(), isTrue, reason: 'missing ${file.path}');
  return Map<String, dynamic>.from(
    jsonDecode(file.readAsStringSync()) as Map,
  );
}

/// `iptv/vod/manifest.json` — IPTV VOD details pack (not a hub tab).
Map<String, dynamic> loadIptvVodPackManifest() {
  final root = _packsRoot();
  expect(root, isNotNull, reason: 'forja-packs not found');
  final file = File('$root/iptv/vod/manifest.json');
  expect(file.existsSync(), isTrue, reason: 'missing ${file.path}');
  return Map<String, dynamic>.from(
    jsonDecode(file.readAsStringSync()) as Map,
  );
}

List<EnginePlugin> loadAllHubPlugins() {
  final out = <EnginePlugin>[];
  for (final dir in [
    'home',
    'anime',
    'asian_drama',
    'arabic',
    'cartoon',
    'aflem',
    'my_list',
    'live_sports',
  ]) {
    final pack = EnginePack.fromJson(
      loadHubPackManifest(dir),
      sourceUrl: 'file:///plugins/hubs/$dir/manifest.json',
    );
    out.addAll(pack.plugins);
  }
  final iptv = EnginePack.fromJson(
    loadIptvVodPackManifest(),
    sourceUrl: 'file:///plugins/iptv/vod/manifest.json',
  );
  out.addAll(iptv.plugins);
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
      expect(envelope.error!.code, MetaErrorCode.authRequired);
      expect(envelope.error!.code.isAuth, isTrue);
      expect(envelope.error!.isRetryable, isFalse);
      expect(
        MetaErrorCode.tryParse('RATE_LIMIT'),
        MetaErrorCode.rateLimit,
      );
      expect(
        MetaErrorCode.tryParse('rate_limit'),
        MetaErrorCode.rateLimit,
        reason: 'casing is normalized',
      );
      expect(MetaErrorCode.tryParse('nope'), isNull);
      expect(MetaErrorCode.upstream.retryableByDefault, isTrue);
      expect(MetaErrorCode.notFound.retryableByDefault, isFalse);
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
      final item = MetaItem.fromJson({
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
      final again = MetaItem.fromJson(item.toJson());
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
      expect(MetaFilterAst.andFilters([null, null]), isNull);
      expect(
        MetaFilterAst.andFilters([MetaFilterAst.eq('genre', 'Action')]),
        {'field': 'genre', 'op': 'eq', 'value': 'Action'},
      );
    });

    test('groups multiple leaves under and', () {
      final ast = MetaFilterAst.andFilters([
        MetaFilterAst.inList('genre', ['Action']),
        MetaFilterAst.eq('year', 2026),
      ]);
      expect(ast!['op'], 'and');
      expect(ast['nodes'], hasLength(2));
    });

    test('parse rejects leaves without a field or value', () {
      expect(MetaFilterAst.parse({'op': 'eq', 'value': 1}), isNull);
      expect(MetaFilterAst.parse({'field': 'genre'}), isNull);
      expect(MetaFilterAst.parse({'op': 'and', 'nodes': []}), isNull);
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

    test('mood options fall back to mood id when no genre', () {
      expect(catalogMoodFilter({'id': 'a', 'genre': 'Action'}), {
        'field': 'genre',
        'op': 'in',
        'value': ['Action'],
      });
      expect(catalogMoodFilter({'id': 'a'}), {
        'field': 'mood',
        'op': 'eq',
        'value': 'a',
      });
    });
  });

  group('chrome filter epoch', () {
    test('pack filters revision bump does not change epoch', () {
      const tabId = 'anime';
      ShellBus.hubSelectedMenuIdFor(tabId).value = null;
      ShellBus.hubSelectedCategoryIdFor(tabId).value = null;
      VerticalFiltersRegistry.selectedIdFor(tabId).value = null;
      final before = catalogChromeFilterEpoch(tabId);
      PackFiltersRegistry.revision.value++;
      expect(catalogChromeFilterEpoch(tabId), before);
    });

    test('menu selection changes epoch', () {
      const tabId = 'anime';
      ShellBus.hubSelectedMenuIdFor(tabId).value = null;
      ShellBus.hubSelectedCategoryIdFor(tabId).value = null;
      VerticalFiltersRegistry.selectedIdFor(tabId).value = null;
      final before = catalogChromeFilterEpoch(tabId);
      ShellBus.hubSelectedMenuIdFor(tabId).value = 'films';
      expect(catalogChromeFilterEpoch(tabId), isNot(before));
      ShellBus.hubSelectedMenuIdFor(tabId).value = null;
    });
  });

  group('hideWhenTypeFilter chrome', () {
    const tabId = 'anime';

    setUp(() {
      PackFiltersRegistry.seedFromJson('anilist', {
        'menus': [
          {
            'id': 'films',
            'label': 'Films',
            'filter': {'op': 'eq', 'field': 'format', 'value': 'MOVIE'},
            'hideTypeFilterRails': true,
          },
          {
            'id': 'series',
            'label': 'Series',
            'filter': {'op': 'eq', 'field': 'format_not', 'value': 'MOVIE'},
            'hideTypeFilterRails': true,
          },
        ],
        'fields': [
          {
            'field': 'genre',
            'options': [
              {'id': 'shonen', 'label': 'Shōnen'},
            ],
          },
        ],
      });
      PluginNavRegistry.seedTestHubNav(
        destinations: {
          tabId: const NavDestination(
            id: tabId,
            icon: Icons.animation_outlined,
            activeIcon: Icons.animation,
            label: 'Anime',
          ),
        },
        tabPluginIds: {tabId: 'anilist'},
      );
    });

    tearDown(() {
      ShellBus.hubSelectedMenuIdFor(tabId).value = null;
      ShellBus.hubSelectedCategoryIdFor(tabId).value = null;
      PackFiltersRegistry.clearForTest();
    });

    test('genre category does not hide type-filter rails', () {
      ShellBus.hubSelectedCategoryIdFor(tabId).value = 'shonen';
      expect(catalogChromeHidesTypeFilterRails(tabId), isFalse);
    });

    test('pack menu with hideTypeFilterRails hides type-filter rails', () {
      ShellBus.hubSelectedMenuIdFor(tabId).value = 'films';
      expect(catalogChromeHidesTypeFilterRails(tabId), isTrue);
      ShellBus.hubSelectedMenuIdFor(tabId).value = 'series';
      expect(catalogChromeHidesTypeFilterRails(tabId), isTrue);
    });
  });

  group('layout feedRails', () {
    test('uses feedRails when declared', () {
      final ids = catalogLayoutFeedRailIds({
        'feed': true,
        'feedRails': ['spotlight', 'latest', 'trending'],
      });
      expect(ids, {'spotlight', 'latest', 'trending'});
    });

    test('falls back to legacy home rails when feedRails omitted', () {
      final ids = catalogLayoutFeedRailIds(
        {'feed': true},
        legacyWhenFeedOnly: {'spotlight', 'featured'},
      );
      expect(ids, {'spotlight', 'featured'});
    });
  });

  group('cache', () {
    setUp(MetaCache.instance.wipeAll);

    test('key is stable across param order', () {
      final a = MetaCache.keyFor(
        pluginId: 'anilist',
        action: 'rail',
        params: {'rail': 'trending', 'limit': 20},
      );
      final b = MetaCache.keyFor(
        pluginId: 'anilist',
        action: 'rail',
        params: {'limit': 20, 'rail': 'trending'},
      );
      expect(a, b);
      expect(a, startsWith('anilist|rail|'));
    });

    test('auth subject and params change the key', () {
      final base = MetaCache.keyFor(pluginId: 'p', action: 'rail');
      expect(
        MetaCache.keyFor(pluginId: 'p', action: 'rail', authSubject: 'u1'),
        isNot(base),
      );
      expect(
        MetaCache.keyFor(pluginId: 'p', action: 'rail', params: {'a': 1}),
        isNot(base),
      );
    });

    test('honours maxAge then the swr window', () {
      const key = 'k';
      MetaCache.instance.put(
        key: key,
        pluginId: 'anilist',
        data: const {'items': []},
        hints: const MetaCacheHints(
          maxAge: Duration(seconds: 1),
          swr: Duration(minutes: 5),
        ),
      );
      final entry = MetaCache.instance.get(key)!;
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
      MetaCache.instance.put(
        key: 'a',
        pluginId: 'anilist',
        data: const {},
      );
      MetaCache.instance.put(key: 'b', pluginId: 'kisskh-hub', data: const {});
      MetaCache.instance.wipePlugin('anilist');
      expect(MetaCache.instance.get('a'), isNull);
      expect(MetaCache.instance.get('b'), isNotNull);
    });

    test('pack version change wipes everything', () {
      MetaCache.instance.syncPackVersion('forjahq-home', '1.0.0');
      MetaCache.instance.put(key: 'a', pluginId: 'anilist', data: const {});
      MetaCache.instance.syncPackVersion('forjahq-home', '1.0.0');
      expect(MetaCache.instance.get('a'), isNotNull);
      MetaCache.instance.syncPackVersion('forjahq-home', '1.0.1');
      expect(MetaCache.instance.get('a'), isNull);
    });
  });

  group('enrich cache skip', () {
    test('details skips when kit marker set', () {
      expect(
        MetaRuntime.envelopeAlreadyEnriched(
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
        MetaRuntime.envelopeAlreadyEnriched(
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
        MetaRuntime.envelopeAlreadyEnriched(
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
        MetaRuntime.envelopeAlreadyEnriched(
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
        MetaRuntime.envelopeAlreadyEnriched(
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
        MetaRuntime.envelopeAlreadyEnriched(
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
      final link = MetaDeepLink.parse(
        'forja://catalog/anilist/details?id=anilist%3A21&from=home',
      )!;
      expect(link.pluginId, 'anilist');
      expect(link.action, 'details');
      expect(link.id, 'anilist:21');
      expect(link.params['from'], 'home');
    });

    test('defaults the action to details', () {
      expect(MetaDeepLink.parse('forja://catalog/tmdb')?.action, 'details');
    });

    test('rejects other schemes and hosts', () {
      expect(MetaDeepLink.parse('https://catalog/anilist/details'), isNull);
      expect(MetaDeepLink.parse('forja://player/anilist'), isNull);
      expect(MetaDeepLink.parse('forja://catalog'), isNull);
    });

    test('round-trips through a uri', () {
      const link = MetaDeepLink(
        pluginId: 'kisskh-hub',
        action: 'details',
        id: 'kisskh:10633',
      );
      expect(MetaDeepLink.parse(link.toString())!.id, 'kisskh:10633');
    });
  });

  group('hub packs', () {
    test('home / anime / asian_drama / arabic manifests declare hub catalog plugins', () {
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
        expect(plugin.isKitPlugin, isTrue, reason: plugin.id);
        expect(plugin.isExtractable, isFalse, reason: plugin.id);
        expect(plugin.needsScript, isTrue, reason: plugin.id);
        expect(plugin.kit, hostKitVersion, reason: plugin.id);
        expect(plugin.protocol, hostProtocolVersion, reason: plugin.id);
        expect(plugin.prelude, '_kit.js', reason: plugin.id);
        if (plugin.hasCapability('enrich') && !plugin.hasCapability('nav')) {
          continue;
        }
        if (plugin.hasCapability('details') && !plugin.hasCapability('nav')) {
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

    test('iptv vod pack is under plugins/iptv/vod, not hubs', () {
      final iptv = EnginePack.fromJson(
        loadIptvVodPackManifest(),
        sourceUrl: 'file:///plugins/iptv/vod/manifest.json',
      );
      expect(iptv.packId, 'forjahq-iptv-vod');
      expect(iptv.plugins.map((p) => p.id), ['iptv-vod', 'iptv-enrich-tmdb']);
      expect(
        PluginRegistry.forjaHqSlot(
          '/Users/me/Forja/plugins/iptv/vod/manifest.json',
        ),
        'iptv-vod',
      );
      expect(
        PluginRegistry.packKindKey(iptv),
        PluginRegistry.packKindIptv,
      );
      expect(
        PluginRegistry.packKindInfo(iptv),
        'IPTV · Iptv Vod',
      );
      for (final plugin in iptv.plugins) {
        expect(plugin.isKitPlugin, isTrue, reason: plugin.id);
        expect(plugin.types, contains('iptv'), reason: plugin.id);
        expect(plugin.hasCapability('nav'), isFalse, reason: plugin.id);
      }
      expect(File('../../plugins/iptv/vod/iptv_vod.js').existsSync(), isTrue);
      expect(
        File('../../plugins/iptv/vod/enrich_tmdb.js').existsSync(),
        isTrue,
      );
    });

    test('legacy hubs/iptv manifest url maps to iptv-vod slot', () {
      expect(
        PluginRegistry.forjaHqSlot(
          '/Users/me/Forja/plugins/hubs/iptv/manifest.json',
        ),
        'iptv-vod',
      );
      expect(
        PluginRegistry.isHubManifestSlot('iptv-vod'),
        isFalse,
      );
    });

    test('iptv-vod details returns protocol envelope array', () {
      final src =
          File('../../plugins/iptv/vod/iptv_vod.js').readAsStringSync();
      expect(src, isNot(contains('iptvVodDetails(params)[0]')));
      expect(src, contains('return Promise.resolve(iptvVodDetails(params));'));
    });

    test('nav specs map plugins onto hub tabs', () {
      final byRail = <String, MetaNavSpec>{};
      for (final dir in [
        'home',
        'anime',
        'asian_drama',
        'arabic',
        'cartoon',
        'aflem',
        'my_list',
        'live_sports',
      ]) {
        final pack = EnginePack.fromJson(
          loadHubPackManifest(dir),
          sourceUrl: 'file:///plugins/hubs/$dir/manifest.json',
        );
        for (final p in pack.plugins) {
          if (p.nav == null) continue;
          final spec = MetaNavSpec.fromPluginNav(
            p.nav,
            pluginId: p.id,
            fallbackLabel: p.name,
          )!;
          final rail = PluginRegistry.hostNavId(
            sourceUrl: pack.sourceUrl,
            authorTabId: spec.tabId,
          );
          byRail[rail] = spec;
        }
      }
      expect(byRail['home']!.pluginId, 'tmdb');
      expect(byRail['anime']!.pluginId, 'anilist');
      expect(byRail['asian_drama']!.pluginId, 'kisskh-hub');
      expect(byRail['arabic']!.pluginId, 'arabic-hub');
      expect(byRail['mylist']!.pluginId, 'my-list-hub');
      expect(byRail['mylist']!.icon, 'icons/nav.png');
      expect(byRail['live_sports']!.pluginId, 'live-sports-hub');
      expect(byRail['live_sports']!.icon, 'icons/nav.png');
      expect(byRail['cartoon']!.pluginId, 'dimatoon-hub');
      expect(byRail['cartoon']!.icon, 'icons/nav.png');
      expect(byRail['live_sports']!.accent, '#FB923C');
      expect(byRail['home']!.accent, '#1CE783');
      expect(byRail['home']!.order, 100);
      // Packs omit tabId — chrome id comes from install URL slot.
      expect(byRail['home']!.tabId, isEmpty);

      // Host seed empty — Live Sports is pack-owned (RFC-087).
      PluginNavRegistry.seedBuiltIns();
      expect(PluginNavRegistry.isKitTab('live_sports'), isFalse);
      expect(PluginNavRegistry.isKitTab('settings'), isFalse);
      expect(PluginNavRegistry.isContributed('mylist'), isFalse);
      expect(PluginNavRegistry.isContributed('iptv'), isTrue);
      expect(PluginNavRegistry.isContributed('live_sports'), isFalse);
      expect(
        PluginNavRegistry.featureTabIds(),
        isNot(contains('iptv')),
      );
      expect(
        PluginNavRegistry.featureTabIds(
          availableAddonFeatureIds: const ['iptv'],
        ),
        contains('iptv'),
      );
      expect(
        PluginNavRegistry.featureTabIds(
          availableAddonFeatureIds: const ['iptv'],
        ),
        isNot(contains('live_sports')),
      );
    });

    test('nav icons are pack-relative — never assets/ or forja://asset', () async {
      final byRail = <String, MetaNavSpec>{};
      for (final dir in [
        'home',
        'anime',
        'asian_drama',
        'arabic',
        'cartoon',
        'aflem',
        'my_list',
        'live_sports',
      ]) {
        final pack = EnginePack.fromJson(
          loadHubPackManifest(dir),
          sourceUrl: 'file:///plugins/hubs/$dir/manifest.json',
        );
        for (final p in pack.plugins) {
          if (p.nav == null) continue;
          final spec = MetaNavSpec.fromPluginNav(
            p.nav,
            pluginId: p.id,
            fallbackLabel: p.name,
          )!;
          final rail = PluginRegistry.hostNavId(
            sourceUrl: pack.sourceUrl,
            authorTabId: spec.tabId,
          );
          byRail[rail] = spec;
        }
      }

      expect(byRail['home']!.icon, 'icons/nav.png');
      expect(byRail['anime']!.icon, 'icons/nav.png');
      expect(byRail['asian_drama']!.icon, 'icons/nav.png');
      expect(byRail['cartoon']!.icon, 'icons/nav.png');
      expect(byRail['mylist']!.icon, 'icons/nav.png');

      for (final e in byRail.entries) {
        final s = e.value;
        final icon = s.icon;
        if (icon == null || icon.isEmpty) {
          expect(
            PluginNavRegistry.iconDataFor(s),
            ForjaHostAssets.defaultNavIcon,
            reason: '${e.key} missing icon → default Material',
          );
          continue;
        }
        expect(
          icon.startsWith('assets/'),
          isFalse,
          reason: '${e.key} must not leak Flutter asset paths',
        );
        expect(
          icon.startsWith('forja://'),
          isFalse,
          reason: '${e.key} must not use host forja://asset URIs',
        );
        expect(
          PackAssets.isPackNavIcon(icon),
          isTrue,
          reason: '${e.key} icon $icon must be pack-relative or http(s)',
        );
      }

      expect(
        PluginNavRegistry.iconDataFor(
          MetaNavSpec.fromPluginNav(
            {
              'label': 'No Icon',
            },
            pluginId: 'test-hub-2',
            fallbackLabel: 'No Icon',
          )!,
        ),
        ForjaHostAssets.defaultNavIcon,
      );
      final cartoonManifest =
          File('../../plugins/hubs/cartoon/manifest.json').resolveSymbolicLinksSync();
      final cartoonIcon =
          File('../../plugins/hubs/cartoon/icons/nav.png').resolveSymbolicLinksSync();
      expect(
        await PackAssets.resolveNavIconDisplay(
          packSourceUrl: Uri.file(cartoonManifest).toString(),
          icon: 'icons/nav.png',
        ),
        cartoonIcon,
      );
      expect(
        await PackAssets.resolveNavIconDisplay(
          packSourceUrl: Uri.file(cartoonManifest).toString(),
          icon: 'forja://asset/nav/home',
        ),
        isNull,
      );
      expect(
        await PackAssets.resolveNavIconDisplay(
          packSourceUrl: Uri.file(cartoonManifest).toString(),
          icon: 'assets/images/nav/home.png',
        ),
        isNull,
      );
    });

    test('resolveNavIconDisplay prefers installed pack disk over CDN URL', () async {
      final root = Directory.systemTemp.createTempSync('forja-nav-icon-');
      addTearDown(() {
        PluginScriptDiskStore.resetForTest();
        try {
          root.deleteSync(recursive: true);
        } catch (_) {}
      });
      PluginScriptDiskStore.debugRoot = root;
      const sourceUrl =
          'https://cdn.example/plugins/hubs/cartoon/manifest.json';
      final bytes =
          File('../../plugins/hubs/cartoon/icons/nav.png').readAsBytesSync();
      await PluginScriptDiskStore.savePackRelativeFile(
        sourceUrl: sourceUrl,
        relative: 'icons/nav.png',
        bytes: bytes,
      );
      final resolved = await PackAssets.resolveNavIconDisplay(
        packSourceUrl: sourceUrl,
        icon: 'icons/nav.png',
      );
      expect(resolved, isNotNull);
      expect(resolved!.startsWith('http'), isFalse);
      expect(File(resolved).existsSync(), isTrue);
    });

    test('resolvePackAssetDisplay prefers disk for Home provider logos', () async {
      final root = Directory.systemTemp.createTempSync('forja-home-logo-');
      addTearDown(() {
        PluginScriptDiskStore.resetForTest();
        try {
          root.deleteSync(recursive: true);
        } catch (_) {}
      });
      PluginScriptDiskStore.debugRoot = root;
      const sourceUrl =
          'https://cdn.example/plugins/hubs/home/manifest.json';
      final bytes =
          File('../../plugins/hubs/home/logos/netflix.svg').readAsBytesSync();
      await PluginScriptDiskStore.savePackRelativeFile(
        sourceUrl: sourceUrl,
        relative: 'logos/netflix.svg',
        bytes: bytes,
      );
      final resolved = await PackAssets.resolvePackAssetDisplay(
        packSourceUrl: sourceUrl,
        relative: 'logos/netflix.svg',
      );
      expect(resolved, isNotNull);
      expect(resolved!.startsWith('http'), isFalse);
      expect(File(resolved).existsSync(), isTrue);
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
      expect(again.isKitPlugin, isTrue);
      expect(again.capabilities, ['nav', 'rail']);
      expect(again.nav!['tabId'], 'custom_tab');
      expect(again.enrich, 'enrich-companion-test');
      expect(again.copyWith(enabled: false).enrich, 'enrich-companion-test');
    });
  });
}
