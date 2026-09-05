import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:forja/shared/catalog/catalog_pack_assets.dart';
import 'package:forja/shared/catalog/forja_host_assets.dart';
import 'package:forja/shared/catalog/shell/catalog_shell.dart';
import 'package:forja/shared/engine/hub_plugin_config.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shell/nav_destination.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hub tabs contributed by `kind: catalog` packs. Shell-core stays in app.
///
/// Destinations / accents / builders come only from pack `nav` ([refresh]).
/// Last [refresh] is cached so boot does not flash an empty rail.
/// No hardcoded pack plugin ids — seed is empty until cache or packs load.
abstract final class PluginNavRegistry {
  static const coreShellNavIds = {
    'iptv',
    'live_matches',
    'settings',
  };

  static const _navCacheKey = 'shell_hub_nav_cache_v1';

  static Map<String, NavDestination> _destinations = {};
  static Map<String, Color> _accents = {};
  static Map<String, TabBuilder> _builders = {};
  static Map<String, String> _tabPluginIds = {};
  static bool _seeded = false;
  static bool _testNavLocked = false;
  /// Set when [refresh] skips an empty-hub prefs wipe because packs are still
  /// hydrating — next successful hub scan restores platform-default visibility.
  static bool _deferredEmptyHubNavSync = false;

  static Map<String, NavDestination> get destinations {
    _ensureSeeded();
    return Map.unmodifiable(_destinations);
  }

  static Map<String, Color> get accents {
    _ensureSeeded();
    return Map.unmodifiable(_accents);
  }

  static Map<String, TabBuilder> get builders {
    _ensureSeeded();
    return Map.unmodifiable(_builders);
  }

  /// True when [id] is a contributed catalog hub tab.
  static bool isHubTab(String id) {
    _ensureSeeded();
    return _destinations.containsKey(id);
  }

  static bool isCoreShell(String id) => coreShellNavIds.contains(id);

  static void _ensureSeeded() {
    if (_seeded) return;
    seedBuiltIns();
  }

  /// Empty in-memory seed — pack `nav` / [_loadCachedNav] fill hubs.
  static void seedBuiltIns() {
    _deferredEmptyHubNavSync = false;
    _destinations = {};
    _accents = {};
    _tabPluginIds = {};
    _builders = {};
    _seeded = true;
  }

  /// Test-only minimal hub nav (no shipped inventory in [seedBuiltIns]).
  @visibleForTesting
  static void seedTestHubNav({
    Map<String, NavDestination>? destinations,
    Map<String, String>? tabPluginIds,
  }) {
    _testNavLocked = true;
    _deferredEmptyHubNavSync = false;
    _destinations = destinations ??
        {
          'test_hub_a': const NavDestination(
            id: 'test_hub_a',
            icon: Icons.grid_view_outlined,
            activeIcon: Icons.grid_view_rounded,
            label: 'Hub A',
          ),
          'test_hub_b': const NavDestination(
            id: 'test_hub_b',
            icon: Icons.grid_view_outlined,
            activeIcon: Icons.grid_view_rounded,
            label: 'Hub B',
          ),
          'test_hub_c': const NavDestination(
            id: 'test_hub_c',
            icon: Icons.grid_view_outlined,
            activeIcon: Icons.grid_view_rounded,
            label: 'Hub C',
          ),
        };
    _accents = {
      'test_hub_a': const Color(0xFFE50914),
      'test_hub_b': const Color(0xFF8B5CF6),
      'test_hub_c': const Color(0xFFEC4899),
    };
    _tabPluginIds = Map<String, String>.from(
      tabPluginIds ??
          const {
            'test_hub_a': 'test-provider-a',
            'test_hub_b': 'test-provider-b',
            'test_hub_c': 'test-provider-c',
          },
    );
    _builders = {
      for (final tabId in _destinations.keys)
        tabId: () => CatalogShellLoader(tabId: tabId),
    };
    _seeded = true;
  }

  static Future<void> _loadCachedNav() async {
    if (_testNavLocked) return;
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_navCacheKey);
      if (raw == null || raw.isEmpty) return;
      final json = jsonDecode(raw);
      if (json is! Map) return;
      _applySnapshot(_snapshotFromJson(Map<String, dynamic>.from(json)));
      SettingsService.navbarChangeNotifier.value++;
    } catch (_) {}
  }

  static Future<void> _persistNavSnapshot({
    required List<Map<String, dynamic>> destinationRows,
  }) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
        _navCacheKey,
        jsonEncode({
          'version': 1,
          'tabPluginIds': _tabPluginIds,
          'destinations': destinationRows,
          'accents': {
            for (final e in _accents.entries)
              e.key:
                  '#${e.value.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
          },
        }),
      );
    } catch (_) {}
  }

  static _NavSnapshot _snapshotFromJson(Map<String, dynamic> json) {
    final tabPluginIds = <String, String>{};
    final rawIds = json['tabPluginIds'];
    if (rawIds is Map) {
      for (final e in rawIds.entries) {
        final k = e.key.toString();
        final v = e.value?.toString() ?? '';
        if (k.isNotEmpty && v.isNotEmpty) tabPluginIds[k] = v;
      }
    }
    final dests = <String, NavDestination>{};
    final rawDests = json['destinations'];
    if (rawDests is List) {
      for (final raw in rawDests) {
        if (raw is! Map) continue;
        final m = Map<String, dynamic>.from(raw);
        final tabId = m['tabId']?.toString() ?? '';
        if (tabId.isEmpty) continue;
        final iconAsset = m['iconAsset']?.toString();
        final material =
            ForjaHostAssets.materialIconFor(m['icon']?.toString()) ??
            ForjaHostAssets.defaultNavIcon;
        dests[tabId] = NavDestination(
          id: tabId,
          icon: material,
          activeIcon: material,
          label: m['label']?.toString() ?? tabId,
          iconAsset: iconAsset,
        );
      }
    }
    final accents = <String, Color>{};
    final rawAccents = json['accents'];
    if (rawAccents is Map) {
      for (final e in rawAccents.entries) {
        final hex = e.value?.toString().trim() ?? '';
        if (hex.isEmpty) continue;
        final h = hex.startsWith('#') ? hex.substring(1) : hex;
        if (h.length == 6) {
          final v = int.tryParse(h, radix: 16);
          if (v != null) accents[e.key.toString()] = Color(0xFF000000 | v);
        }
      }
    }
    return _NavSnapshot(
      destinations: dests,
      accents: accents,
      tabPluginIds: tabPluginIds,
    );
  }

  static void _applySnapshot(_NavSnapshot snap) {
    _destinations = snap.destinations;
    _accents = snap.accents;
    _tabPluginIds = Map<String, String>.from(snap.tabPluginIds);
    _builders = {
      for (final tabId in _destinations.keys)
        tabId: () {
          final pluginId = _tabPluginIds[tabId];
          if (pluginId != null && pluginId.isNotEmpty) {
            return CatalogShell(pluginId: pluginId, tabId: tabId);
          }
          return CatalogShellLoader(tabId: tabId);
        },
    };
    _seeded = true;
  }

  /// Hub tab currently contributed by an enabled pack+plugin.
  static bool isContributed(String tabId) {
    _ensureSeeded();
    if (coreShellNavIds.contains(tabId)) return true;
    return _destinations.containsKey(tabId);
  }

  static Future<List<EnginePlugin>> listHubPlugins({
    bool requireEnabled = true,
  }) async {
    final packs = await EngineService.instance.listPacks();
    final out = <EnginePlugin>[];
    for (final p in packs) {
      if (requireEnabled && !p.enabled) continue;
      for (final pl in p.plugins) {
        if (!pl.isHubCatalog) continue;
        if (requireEnabled && !pl.enabled) continue;
        out.add(pl);
      }
    }
    return out;
  }

  static Future<List<(EnginePack, EnginePlugin, CatalogNavSpec)>> listNavHubs({
    bool requireEnabled = true,
  }) async {
    final packs = await EngineService.instance.listPacks();
    final out = <(EnginePack, EnginePlugin, CatalogNavSpec)>[];
    for (final pack in packs) {
      if (requireEnabled && !pack.enabled) continue;
      for (final pl in pack.plugins) {
        if (!pl.isHubCatalog) continue;
        if (requireEnabled && !pl.enabled) continue;
        if (!pl.hasCapability('nav')) continue;
        final spec = CatalogNavSpec.fromPluginNav(
          pl.nav,
          pluginId: pl.id,
          fallbackLabel: pl.name,
        );
        if (spec == null || !spec.isValid) continue;
        out.add((pack, pl, spec));
      }
    }
    out.sort((a, b) => a.$3.order.compareTo(b.$3.order));
    return out;
  }

  static Future<Set<String>> _hubTabIdsFromNavConfig() async {
    final raw = await SettingsService().getNavbarConfig();
    return raw.where((id) {
      if (coreShellNavIds.contains(id)) return false;
      if (id == 'settings') return false;
      return true;
    }).toSet();
  }

  static Future<void> _clearNavSnapshot() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_navCacheKey);
    } catch (_) {}
  }

  /// True while hub `nav` cannot be scanned yet — lean stubs, splash download,
  /// or empty pack index before cloud sync. Must not [syncActiveHubNavIds]
  /// with an empty active set (that permanently strips Features defaults).
  static Future<bool> _hubNavHydrationPending() async {
    final coordinator = PluginInstallCoordinator.instance;
    if (coordinator.isBootWarm || coordinator.isInstalling) return true;

    final packs = await PluginRegistry.instance.listPacksRaw();
    if (packs.isEmpty) {
      // First boot / pre-sync: index not ready. After splash with a real empty
      // install, allow the empty-hub wipe.
      return !ShellBus.splashDismissed.value;
    }
    for (final pack in packs) {
      if (PluginRegistry.isLegacyAssetPack(pack.sourceUrl)) continue;
      // Cloud lean rows are URL-only until full install fills plugins + nav.
      if (pack.plugins.isEmpty) return true;
    }
    return false;
  }

  static Future<bool> refresh() async {
    _ensureSeeded();
    if (!_testNavLocked && _destinations.isEmpty && _tabPluginIds.isEmpty) {
      await _loadCachedNav();
    }
    final previousDestKeys = _destinations.keys.toSet();
    final installed = await listNavHubs(requireEnabled: false);
    final navConfigHubIds = await _hubTabIdsFromNavConfig();
    final allKnownHubTabIds = <String>{
      for (final (_, _, nav) in installed) nav.tabId,
      ...previousDestKeys,
      ...navConfigHubIds,
    };

    if (installed.isEmpty) {
      if (await _hubNavHydrationPending()) {
        // Keep seed/cache + saved Features visibility until packs contribute nav.
        _deferredEmptyHubNavSync = true;
        return false;
      }
      final hadHubs = previousDestKeys.isNotEmpty;
      _destinations = {};
      _accents = {};
      _builders = {};
      _tabPluginIds = {};
      _seeded = true;
      await _clearNavSnapshot();
      if (allKnownHubTabIds.isNotEmpty) {
        await SettingsService().syncActiveHubNavIds(
          activeHubIds: const {},
          knownHubIds: allKnownHubTabIds.difference(coreShellNavIds),
        );
      }
      if (hadHubs) {
        SettingsService.navbarChangeNotifier.value++;
      }
      return hadHubs;
    }

    final hubs = await listNavHubs(requireEnabled: true);

    final dests = <String, NavDestination>{};
    final accents = <String, Color>{};
    final builders = <String, TabBuilder>{};
    final tabPluginIds = <String, String>{};
    final extras = <String>[];
    final cacheRows = <Map<String, dynamic>>[];
    final allHubTabIds = <String>{
      for (final (_, _, nav) in installed) nav.tabId,
      ...previousDestKeys,
    };

    for (final (pack, pl, nav) in hubs) {
      final iconAsset = CatalogPackAssets.resolveNavIconDisplay(
        packSourceUrl: pack.sourceUrl,
        icon: nav.icon,
      );
      final material = iconDataFor(nav);
      dests[nav.tabId] = NavDestination(
        id: nav.tabId,
        icon: material,
        activeIcon: material,
        label: nav.label,
        iconAsset: iconAsset,
      );
      builders[nav.tabId] = () =>
          CatalogShell(pluginId: pl.id, tabId: nav.tabId);
      tabPluginIds[nav.tabId] = pl.id;
      final accent = accentFor(nav);
      if (accent != null) accents[nav.tabId] = accent;
      if (!SettingsService.allNavIds.contains(nav.tabId)) {
        extras.add(nav.tabId);
      }
      cacheRows.add({
        'tabId': nav.tabId,
        'label': nav.label,
        'icon': nav.icon,
        'iconAsset': iconAsset,
      });
    }

    final changed =
        !_mapEq(_destinations, dests) ||
        !_colorMapEq(_accents, accents) ||
        !_builderKeysEq(_builders, builders) ||
        !_tabPluginIdsEq(_tabPluginIds, tabPluginIds);

    _destinations = dests;
    _accents = accents;
    _builders = builders;
    _tabPluginIds = tabPluginIds;
    _seeded = true;

    if (extras.isNotEmpty) {
      SettingsService.registerExtraNavIds(extras);
    }
    if (dests.isNotEmpty || extras.isNotEmpty) {
      // Pack hub tabs only — never auto-show Addons-gated core (`iptv` / `live_matches`).
      await SettingsService().ensureNavIdsKnown(
        allHubIds: dests.keys
            .where((id) => !coreShellNavIds.contains(id))
            .toList(),
      );
    }
    if (_deferredEmptyHubNavSync && dests.isNotEmpty) {
      _deferredEmptyHubNavSync = false;
      // VOD hubs only — never force-on Addons-gated core tabs (iptv / live_matches).
      await SettingsService().ensureActiveDefaultHubsVisible(
        activeHubIds: dests.keys.toSet().difference(coreShellNavIds),
      );
    }
    await SettingsService().syncActiveHubNavIds(
      activeHubIds: dests.keys.toSet().difference(coreShellNavIds),
      knownHubIds: allHubTabIds.difference(coreShellNavIds),
    );
    if (dests.isNotEmpty) {
      await _persistNavSnapshot(destinationRows: cacheRows);
    } else {
      await _clearNavSnapshot();
    }
    if (changed) {
      SettingsService.navbarChangeNotifier.value++;
    }
    return changed;
  }

  static String? pluginIdForTabSync(String tabId) {
    _ensureSeeded();
    return _tabPluginIds[tabId];
  }

  static String? tabIdForPluginSync(String pluginId) {
    _ensureSeeded();
    for (final e in _tabPluginIds.entries) {
      if (e.value == pluginId) return e.key;
    }
    return null;
  }

  static Future<String?> pluginIdForTab(String tabId) async {
    _ensureSeeded();
    final cached = _tabPluginIds[tabId];
    if (cached != null && cached.isNotEmpty) return cached;
    for (final (_, pl, nav) in await listNavHubs(requireEnabled: true)) {
      if (nav.tabId == tabId) return pl.id;
    }
    final plugin = await HubPluginConfig.catalogPluginForTab(tabId);
    return plugin?.id;
  }

  /// First enabled hub whose pack declares [typeToken] in `engine.types`.
  ///
  /// Prefers source plugins (`details` / `nav` / `feed`) over enrich-only
  /// companions (`iptv-vod` before `iptv-enrich-tmdb`, etc.).
  static Future<String?> pluginIdForEngineType(String typeToken) async {
    final want = typeToken.trim();
    if (want.isEmpty) return null;
    String? enrichFallback;
    for (final pl in await listHubPlugins()) {
      if (!pl.types.contains(want)) continue;
      if (pl.hasCapability('details') ||
          pl.hasCapability('nav') ||
          pl.hasCapability('feed')) {
        return pl.id;
      }
      enrichFallback ??= pl.id;
    }
    return enrichFallback;
  }

  /// Resolve hub plugin id without hardcoded tab or pack ids.
  static Future<String?> resolveHubPluginId({
    String? pluginId,
    String? tabId,
    String? engineType,
  }) async {
    final direct = pluginId?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final tab = tabId?.trim();
    if (tab != null && tab.isNotEmpty) {
      final fromTab = await pluginIdForTab(tab);
      if (fromTab != null && fromTab.isNotEmpty) return fromTab;
    }
    final type = engineType?.trim();
    if (type != null && type.isNotEmpty) {
      final fromType = await pluginIdForEngineType(type);
      if (fromType != null && fromType.isNotEmpty) return fromType;
    }
    final hubs = await listNavHubs(requireEnabled: true);
    if (hubs.isNotEmpty) return hubs.first.$2.id;
    return null;
  }

  static Future<bool> isHubPluginEnabled(String pluginId) async {
    final want = pluginId.trim();
    if (want.isEmpty) return false;
    final hit = PluginRegistry.packPluginFromPacks(
      await EngineService.instance.listPacks(),
      want,
    );
    if (hit == null || !hit.plugin.isHubCatalog) return false;
    return hit.pack.isPluginActive(hit.plugin);
  }

  static IconData iconDataFor(CatalogNavSpec nav) {
    return ForjaHostAssets.materialIconFor(nav.icon) ??
        ForjaHostAssets.defaultNavIcon;
  }

  static Color? accentFor(CatalogNavSpec nav) {
    final a = nav.accent?.trim();
    if (a == null || a.isEmpty) return null;
    final hex = a.startsWith('#') ? a.substring(1) : a;
    if (hex.length == 6) {
      final v = int.tryParse(hex, radix: 16);
      if (v != null) return Color(0xFF000000 | v);
    }
    return null;
  }

  static bool _mapEq(
    Map<String, NavDestination> a,
    Map<String, NavDestination> b,
  ) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      final o = b[e.key];
      if (o == null ||
          o.label != e.value.label ||
          o.iconAsset != e.value.iconAsset) {
        return false;
      }
    }
    return true;
  }

  static bool _colorMapEq(Map<String, Color> a, Map<String, Color> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  static bool _builderKeysEq(
    Map<String, TabBuilder> a,
    Map<String, TabBuilder> b,
  ) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k)) return false;
    }
    return true;
  }

  static bool _tabPluginIdsEq(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }
}

class _NavSnapshot {
  const _NavSnapshot({
    required this.destinations,
    required this.accents,
    required this.tabPluginIds,
  });

  final Map<String, NavDestination> destinations;
  final Map<String, Color> accents;
  final Map<String, String> tabPluginIds;
}
