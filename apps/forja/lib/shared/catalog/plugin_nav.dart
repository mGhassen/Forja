import 'package:flutter/material.dart';
import 'package:forja/shared/catalog/forja_host_assets.dart';
import 'package:forja/shared/catalog/shell/catalog_shell.dart';
import 'package:forja/shared/engine/hub_plugin_config.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shell/nav_destination.dart';
import 'package:rust/rust.dart';

/// Hub tabs owned by `kind: catalog` plugins. Shell-core stays in app.
///
/// Destinations / accents / builders are rebuilt from plugin `nav` specs
/// ([refresh]). Until the first successful refresh, [seedBuiltIns] keeps the
/// official hub tabs available so the rail and Features UI do not flash empty.
abstract final class PluginNavRegistry {
  static const coreShellNavIds = {
    'mylist',
    'iptv',
    'live_matches',
    'settings',
  };

  static const hubTabIds = {
    'home',
    'anime',
    'asian_drama',
  };

  /// Default shell tab ids for in-scope catalog hubs (icons only — no plugin ids).
  static const seedHubTabIds = ['home', 'anime', 'asian_drama'];

  static Map<String, NavDestination> _destinations = {};
  static Map<String, Color> _accents = {};
  static Map<String, TabBuilder> _builders = {};
  static Map<String, String> _tabPluginIds = {};
  static bool _seeded = false;

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

  /// True when [id] is a contributed (or seeded) catalog hub tab.
  static bool isHubTab(String id) {
    _ensureSeeded();
    return _destinations.containsKey(id);
  }

  static bool isCoreShell(String id) => coreShellNavIds.contains(id);

  static void _ensureSeeded() {
    if (_seeded) return;
    seedBuiltIns();
  }

  /// Synchronous seed for required in-scope hubs (Home / Anime / Asian Drama).
  /// Optional hubs (Arabic) appear only after [refresh] when their pack is on.
  static void seedBuiltIns() {
    _destinations = {
      'home': const NavDestination(
        id: 'home',
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        label: 'Home',
        iconAsset: ForjaHostAssets.flutterNavHome,
      ),
      'anime': const NavDestination(
        id: 'anime',
        icon: Icons.animation_outlined,
        activeIcon: Icons.animation,
        label: 'Anime',
        iconAsset: ForjaHostAssets.flutterNavAnime,
      ),
      'asian_drama': const NavDestination(
        id: 'asian_drama',
        icon: Icons.theater_comedy_outlined,
        activeIcon: Icons.theater_comedy,
        label: 'Asian Drama',
        iconAsset: ForjaHostAssets.flutterNavAsianDrama,
      ),
    };
    _accents = {
      'home': const Color(0xFF1CE783),
      'anime': const Color(0xFFFB7185),
      'asian_drama': const Color(0xFFC4B5FD),
    };
    _builders = {
      for (final tabId in seedHubTabIds)
        tabId: () => CatalogShellLoader(tabId: tabId),
    };
    _tabPluginIds = {};
    _seeded = true;
  }

  /// Hub tab currently contributed by an enabled pack+plugin (or seed).
  static bool isContributed(String tabId) {
    _ensureSeeded();
    if (!hubTabIds.contains(tabId)) return true;
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

  /// Hub plugins that declare `nav` — for Features / shell destinations.
  ///
  /// Only **enabled** pack+plugin hubs contribute (disabled → gone from Features
  /// and the rail). Features show/hide still applies among contributed hubs.
  static Future<List<(EnginePlugin, CatalogNavSpec)>> listNavHubs({
    bool requireEnabled = true,
  }) async {
    final plugins = await listHubPlugins(requireEnabled: requireEnabled);
    final out = <(EnginePlugin, CatalogNavSpec)>[];
    for (final pl in plugins) {
      if (!pl.hasCapability('nav')) continue;
      final spec = CatalogNavSpec.fromPluginNav(
        pl.nav,
        pluginId: pl.id,
        fallbackLabel: pl.name,
      );
      if (spec == null || !spec.isValid) continue;
      out.add((pl, spec));
    }
    out.sort((a, b) => a.$2.order.compareTo(b.$2.order));
    return out;
  }

  /// Rebuild hub destinations / accents / builders from enabled pack nav.
  ///
  /// Returns true when the contribution changed. Registers new `tabId`s and
  /// drops disabled hubs from Features / navbar visibility.
  static Future<bool> refresh() async {
    _ensureSeeded();
    // Installed hubs (any enable state) — empty means packs not ready yet.
    final installed = await listNavHubs(requireEnabled: false);
    if (installed.isEmpty) return false;
    final hubs = await listNavHubs(requireEnabled: true);

    final dests = <String, NavDestination>{};
    final accents = <String, Color>{};
    final builders = <String, TabBuilder>{};
    final tabPluginIds = <String, String>{};
    final extras = <String>[];
    final defaultOn = <String>[];

    for (final (pl, nav) in hubs) {
      // Plugins must use forja://asset/… — never Flutter assets/ paths.
      final iconAsset = ForjaHostAssets.resolveFlutterPath(nav.icon);
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
      if (nav.defaultEnabled) defaultOn.add(nav.tabId);
    }

    final changed =
        !_mapEq(_destinations, dests) ||
        !_colorMapEq(_accents, accents) ||
        !_builderKeysEq(_builders, builders);

    _destinations = dests;
    _accents = accents;
    _builders = builders;
    _tabPluginIds = tabPluginIds;
    _seeded = true;

    if (extras.isNotEmpty) {
      SettingsService.registerExtraNavIds(extras);
    }
    if (defaultOn.isNotEmpty || extras.isNotEmpty) {
      await SettingsService().ensureNavIdsKnown(
        defaultEnabledIds: defaultOn,
        allHubIds: dests.keys.toList(),
      );
    }
    await SettingsService().syncActiveHubNavIds(
      activeHubIds: dests.keys.toSet(),
      knownHubIds: hubTabIds,
    );
    // Features filters by contribution — bump even when visible list unchanged
    // (e.g. Arabic was already Features-off but still listed).
    if (changed) {
      SettingsService.navbarChangeNotifier.value++;
    }
    return changed;
  }

  /// Cached tab → plugin id (seed + last [refresh]).
  static String? pluginIdForTabSync(String tabId) {
    _ensureSeeded();
    return _tabPluginIds[tabId];
  }

  /// Cached plugin id → shell tab id (seed + last [refresh]).
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
    for (final (pl, nav) in await listNavHubs(requireEnabled: true)) {
      if (nav.tabId == tabId) return pl.id;
    }
    final plugin = await HubPluginConfig.catalogPluginForTab(tabId);
    return plugin?.id;
  }

  /// Whether the hub plugin (and its pack) are enabled to *run*.
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

  /// Material fallback when [nav.icon] is a known host asset id (or legacy token).
  /// Never branch on [CatalogNavSpec.tabId] — packs own tab identity.
  static IconData iconDataFor(CatalogNavSpec nav) {
    final icon = nav.icon ?? '';
    final id = ForjaHostAssets.parseId(icon);
    if (id == 'nav/home') return Icons.home_outlined;
    if (id == 'nav/anime') return Icons.animation_outlined;
    if (id == 'nav/asian-drama') return Icons.theater_comedy_outlined;
    if (id == 'nav/arabic') return Icons.movie_filter_outlined;
    if (icon == 'movie_filter') return Icons.movie_filter_outlined;
    return Icons.grid_view_rounded;
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
}
