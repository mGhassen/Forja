import 'package:flutter/material.dart';
import 'package:forja/shared/catalog/shell/catalog_shell.dart';
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
    'search',
  };

  static const hubTabIds = {
    'home',
    'anime',
    'asian_drama',
    'arabic',
    'anime_arabic',
  };

  /// Default plugin id for each built-in hub tab (official hubs pack).
  static const builtInHubPluginIds = {
    'home': 'tmdb',
    'anime': 'anilist',
    'asian_drama': 'kisskh-hub',
    'arabic': 'arabic-hub',
  };

  static Map<String, NavDestination> _destinations = {};
  static Map<String, Color> _accents = {};
  static Map<String, TabBuilder> _builders = {};
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

  static bool isHubTab(String id) =>
      hubTabIds.contains(id) || _destinations.containsKey(id);

  static bool isCoreShell(String id) => coreShellNavIds.contains(id);

  static void _ensureSeeded() {
    if (_seeded) return;
    seedBuiltIns();
  }

  /// Synchronous seed matching official hub pack nav blocks.
  static void seedBuiltIns() {
    _destinations = {
      'home': const NavDestination(
        id: 'home',
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        label: 'Home',
        iconAsset: 'assets/images/nav/home.png',
      ),
      'anime': const NavDestination(
        id: 'anime',
        icon: Icons.animation_outlined,
        activeIcon: Icons.animation,
        label: 'Anime',
        iconAsset: 'assets/images/nav/anime.png',
      ),
      'asian_drama': const NavDestination(
        id: 'asian_drama',
        icon: Icons.theater_comedy_outlined,
        activeIcon: Icons.theater_comedy,
        label: 'Asian Drama',
        iconAsset: 'assets/images/nav/asian-drama.png',
      ),
      'arabic': const NavDestination(
        id: 'arabic',
        icon: Icons.movie_filter_outlined,
        activeIcon: Icons.movie_filter,
        label: 'Arabic',
      ),
    };
    _accents = {
      'home': const Color(0xFF1CE783),
      'anime': const Color(0xFFFB7185),
      'asian_drama': const Color(0xFFC4B5FD),
      'arabic': const Color(0xFFF59E0B),
    };
    _builders = {
      for (final e in builtInHubPluginIds.entries)
        e.key: () => CatalogShell(pluginId: e.value, tabId: e.key),
    };
    _seeded = true;
  }

  static Future<List<EnginePlugin>> listHubPlugins({
    bool requireEnabled = true,
  }) async {
    final packs = await EngineService.instance.listPacks();
    final out = <EnginePlugin>[];
    for (final p in packs) {
      // Pack may be disabled — still list hubs so Features keeps the row.
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
  /// **Not** gated on plugin enable: Sources → Forja toggles whether the hub
  /// *runs*; Settings → Features toggles whether the tab *shows*.
  static Future<List<(EnginePlugin, CatalogNavSpec)>> listNavHubs({
    bool requireEnabled = false,
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

  /// Rebuild hub destinations / accents / builders from installed pack nav.
  ///
  /// Returns true when the contribution changed. Registers any new `tabId`s
  /// with [SettingsService] so Features / navbar config can see them — including
  /// hubs whose plugin is currently disabled.
  static Future<bool> refresh() async {
    _ensureSeeded();
    final hubs = await listNavHubs(requireEnabled: false);
    if (hubs.isEmpty) return false;

    final dests = <String, NavDestination>{};
    final accents = <String, Color>{};
    final builders = <String, TabBuilder>{};
    final extras = <String>[];
    final defaultOn = <String>[];

    for (final (pl, nav) in hubs) {
      final iconAsset =
          (nav.icon != null && nav.icon!.startsWith('assets/')) ? nav.icon : null;
      final material = iconDataFor(nav);
      dests[nav.tabId] = NavDestination(
        id: nav.tabId,
        icon: material,
        activeIcon: material,
        label: nav.label,
        iconAsset: iconAsset,
      );
      builders[nav.tabId] = () => CatalogShell(
            pluginId: pl.id,
            tabId: nav.tabId,
          );
      final accent = accentFor(nav);
      if (accent != null) accents[nav.tabId] = accent;
      if (!SettingsService.allNavIds.contains(nav.tabId)) {
        extras.add(nav.tabId);
      }
      if (nav.defaultEnabled) defaultOn.add(nav.tabId);
    }

    final changed = !_mapEq(_destinations, dests) ||
        !_colorMapEq(_accents, accents) ||
        !_builderKeysEq(_builders, builders);

    _destinations = dests;
    _accents = accents;
    _builders = builders;
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
    return changed;
  }

  static Future<String?> pluginIdForTab(String tabId) async {
    for (final (pl, nav) in await listNavHubs(requireEnabled: false)) {
      if (nav.tabId == tabId) return pl.id;
    }
    return builtInHubPluginIds[tabId];
  }

  /// Whether the hub plugin (and its pack) are enabled to *run*.
  /// Independent of Settings → Features visibility.
  static Future<bool> isHubPluginEnabled(String pluginId) async {
    final want = pluginId.trim();
    if (want.isEmpty) return false;
    for (final pack in await EngineService.instance.listPacks()) {
      for (final pl in pack.plugins) {
        if (pl.id != want) continue;
        return pack.enabled && pl.enabled && pl.isHubCatalog;
      }
    }
    return false;
  }

  static IconData iconDataFor(CatalogNavSpec nav) {
    final icon = nav.icon ?? '';
    if (icon.contains('home')) return Icons.home_outlined;
    if (icon.contains('anime')) return Icons.animation_outlined;
    if (icon.contains('asian') || icon.contains('drama')) {
      return Icons.theater_comedy_outlined;
    }
    if (icon == 'movie_filter' || icon.contains('arabic')) {
      return Icons.movie_filter_outlined;
    }
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
