import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/foundation/protocol/pack_capabilities.dart';
import 'package:forja/shared/foundation/components/chrome/pack_filters.dart';
import 'package:forja/shared/foundation/components/chrome/vertical_filters.dart';
import 'package:forja/shared/foundation/components/layout/kit_top_bar.dart';
import 'package:forja/shared/foundation/components/layout/kit_top_menu_registry.dart';
import 'package:forja/shared/foundation/services/nav/plugin_nav.dart';
import 'package:forja/shared/foundation/blocks/shell/kit_search_screen.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:rust/rust.dart';
import 'package:forja/shell/routing/app_router.dart';
import 'package:forja/shell/chrome/kit_chrome_top_bar.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:forja/shell/routing/shell_overlay_navigator.dart';

/// Open hub Search — same entry for top-bar and Cmd+F (when not already overlay).
///
/// Pack capability [PackCapabilities.hostSearch] → shared host Search
/// overlay (structured TMDB + addons). Otherwise pack `search` via
/// [KitSearchScreen].
Future<void> openKitSearch(
  BuildContext context, {
  required String pluginId,
  required String tabId,
  required String hintText,
}) async {
  final found = await PluginRegistry.instance.findPlugin(pluginId);
  final plugin = found?.plugin;
  if (plugin == null || !plugin.hasCapability(PackCapabilities.search)) {
    return;
  }
  if (!context.mounted) return;

  // Host Search overlay = Cmd+F surface (RFC-058 + Stremio addons).
  if (plugin.hasCapability(PackCapabilities.hostSearch)) {
    await AppRouter.openSearch(context);
    return;
  }

  pushShellRoute(
    context,
    AppRouter.slideShellRoute(
      (_) => KitSearchScreen(
        pluginId: pluginId,
        tabId: tabId,
        hintText: hintText,
        structuredSearch: plugin.hasCapability(
          PackCapabilities.structuredSearch,
        ),
        applyChromeFilters: plugin.hasCapability(
          PackCapabilities.filters,
        ),
      ),
    ),
  );
}

/// Generic catalog hub top bar — [tabId] resolves [pluginId] from nav registry.
class PluginKitTopBar extends StatefulWidget {
  const PluginKitTopBar({super.key, required this.tabId});

  final String tabId;

  @override
  State<PluginKitTopBar> createState() => _PluginKitTopBarState();
}

class _PluginKitTopBarState extends State<PluginKitTopBar> {
  EnginePlugin? _plugin;

  @override
  void initState() {
    super.initState();
    SettingsService.navbarChangeNotifier.addListener(_onNavbarChanged);
    EngineService.changeNotifier.addListener(_onEngineChanged);
    _schedulePackFiltersLoad();
    PackFiltersRegistry.revision.addListener(_onFilters);
    KitTopMenuRegistry.revision.addListener(_onFilters);
  }

  @override
  void didUpdateWidget(covariant PluginKitTopBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Shell reuses this State across hub tabs when unkeyed — never keep the
    // previous tab's EnginePlugin (Home search/filters → Live Sports).
    if (oldWidget.tabId == widget.tabId) return;
    _plugin = null;
    _schedulePackFiltersLoad();
  }

  void _schedulePackFiltersLoad() {
    final pluginId = PluginNavRegistry.pluginIdForTabSync(widget.tabId);
    if (pluginId == null) return;
    unawaited(_loadPluginAndFilters(pluginId));
  }

  Future<void> _loadPluginAndFilters(String pluginId) async {
    final found = await PluginRegistry.instance.findPlugin(pluginId);
    if (!mounted) return;
    // Drop stale results if the user switched tabs while findPlugin was in flight.
    if (PluginNavRegistry.pluginIdForTabSync(widget.tabId) != pluginId) {
      return;
    }
    setState(() => _plugin = found?.plugin);
    if (found?.plugin.hasCapability(PackCapabilities.filters) == true) {
      await PackFiltersRegistry.ensureLoaded(pluginId);
      if (!mounted) return;
      if (PluginNavRegistry.pluginIdForTabSync(widget.tabId) != pluginId) {
        return;
      }
      setState(() {});
    }
  }

  void _onNavbarChanged() {
    if (!mounted) return;
    if (_pluginForTab != null) return;
    _schedulePackFiltersLoad();
  }

  void _onEngineChanged() {
    if (!mounted) return;
    final pluginId = PluginNavRegistry.pluginIdForTabSync(widget.tabId);
    if (pluginId == null) return;
    PackFiltersRegistry.invalidate(pluginId);
    unawaited(_loadPluginAndFilters(pluginId));
  }

  @override
  void dispose() {
    SettingsService.navbarChangeNotifier.removeListener(_onNavbarChanged);
    EngineService.changeNotifier.removeListener(_onEngineChanged);
    PackFiltersRegistry.revision.removeListener(_onFilters);
    KitTopMenuRegistry.revision.removeListener(_onFilters);
    super.dispose();
  }

  void _onFilters() {
    if (mounted) setState(() {});
  }

  /// Only trust [_plugin] when it matches this tab's pack (guards State reuse).
  EnginePlugin? get _pluginForTab {
    final pluginId = PluginNavRegistry.pluginIdForTabSync(widget.tabId);
    if (pluginId == null || _plugin == null) return null;
    return _plugin!.id == pluginId ? _plugin : null;
  }

  /// nav+layout hubs (Live Sports) own in-page chrome — no VOD Search/Films bar.
  bool _layoutOnlyHub(EnginePlugin? plugin) {
    if (plugin == null) return false;
    final caps = plugin.capabilities.map((c) => c.toLowerCase()).toSet();
    if (!caps.contains('nav') || !caps.contains('layout')) return false;
    const browse = {
      'rail',
      'feed',
      'search',
      'filters',
      'host_search',
      'structured_search',
      'details',
    };
    return caps.intersection(browse).isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (KitTopMenuRegistry.hasTopMenu(widget.tabId)) {
      return KitTopBar(tabId: widget.tabId);
    }
    return _buildBrowseTopBar(context);
  }

  Widget _buildBrowseTopBar(BuildContext context) {
    final pluginId = PluginNavRegistry.pluginIdForTabSync(widget.tabId);
    if (pluginId == null) return const SizedBox.shrink();
    final plugin = _pluginForTab;
    if (_layoutOnlyHub(plugin)) return const SizedBox.shrink();
    final canSearch =
        plugin?.hasCapability(PackCapabilities.search) ?? false;
    final canFilters =
        plugin?.hasCapability(PackCapabilities.filters) ?? false;
    final hasVerticalFilters =
        VerticalFiltersRegistry.specFor(widget.tabId) != null;
    if (!canSearch && !canFilters && !hasVerticalFilters) {
      return const SizedBox.shrink();
    }
    final label =
        PluginNavRegistry.destinations[widget.tabId]?.label ?? 'Search';
    final categories = PackFiltersRegistry.categoriesFor(pluginId);
    final menus = PackFiltersRegistry.menusFor(pluginId);
    final selectedMenu = ShellBus.hubSelectedMenuIdFor(widget.tabId);
    // Drop stale menu id when this pack no longer declares it.
    final currentMenu = selectedMenu.value;
    if (currentMenu != null &&
        PackFiltersRegistry.menuById(pluginId, currentMenu) == null) {
      selectedMenu.value = null;
    }
    return KitChromeTopBar(
      tabId: widget.tabId,
      selectedMenuId: selectedMenu,
      selectedCategoryId: ShellBus.hubSelectedCategoryIdFor(widget.tabId),
      menus: menus,
      categories: categories,
      scrollOffset: ShellBus.hubScrollOffsetFor(widget.tabId),
      heroHeight: ShellBus.hubHeroHeightFor(widget.tabId),
      onSearch: canSearch
          ? () {
              unawaited(
                openKitSearch(
                  context,
                  pluginId: pluginId,
                  tabId: widget.tabId,
                  hintText: 'Search $label…',
                ),
              );
            }
          : null,
    );
  }
}
