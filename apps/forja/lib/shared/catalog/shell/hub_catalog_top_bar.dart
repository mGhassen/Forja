import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/catalog/catalog_hub_capabilities.dart';
import 'package:forja/shared/catalog/kit/chrome/catalog_pack_filters.dart';
import 'package:forja/shared/catalog/kit/chrome/catalog_vertical_filters.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_kit_top_bar.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_kit_top_menu_registry.dart';
import 'package:forja/shared/catalog/plugin_nav.dart';
import 'package:forja/shared/catalog/shell/catalog_search_screen.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:rust/rust.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shell/catalog_top_bar.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';

/// Open hub Search — same entry for top-bar and Cmd+F (when not already overlay).
///
/// Pack capability [CatalogHubCapabilities.hostSearch] → shared host Search
/// overlay (structured TMDB + addons). Otherwise pack `search` via
/// [CatalogSearchScreen].
Future<void> openHubCatalogSearch(
  BuildContext context, {
  required String pluginId,
  required String tabId,
  required String hintText,
}) async {
  final found = await PluginRegistry.instance.findPlugin(pluginId);
  final plugin = found?.plugin;
  if (plugin == null || !plugin.hasCapability(CatalogHubCapabilities.search)) {
    return;
  }
  if (!context.mounted) return;

  // Host Search overlay = Cmd+F surface (RFC-058 + Stremio addons).
  if (plugin.hasCapability(CatalogHubCapabilities.hostSearch)) {
    await AppRouter.openSearch(context);
    return;
  }

  pushShellRoute(
    context,
    AppRouter.slideShellRoute(
      (_) => CatalogSearchScreen(
        pluginId: pluginId,
        tabId: tabId,
        hintText: hintText,
        structuredSearch: plugin.hasCapability(
          CatalogHubCapabilities.structuredSearch,
        ),
        applyChromeFilters: plugin.hasCapability(
          CatalogHubCapabilities.filters,
        ),
      ),
    ),
  );
}

/// Generic catalog hub top bar — [tabId] resolves [pluginId] from nav registry.
class PluginHubCatalogTopBar extends StatefulWidget {
  const PluginHubCatalogTopBar({super.key, required this.tabId});

  final String tabId;

  @override
  State<PluginHubCatalogTopBar> createState() => _PluginHubCatalogTopBarState();
}

class _PluginHubCatalogTopBarState extends State<PluginHubCatalogTopBar> {
  EnginePlugin? _plugin;

  @override
  void initState() {
    super.initState();
    SettingsService.navbarChangeNotifier.addListener(_onNavbarChanged);
    EngineService.changeNotifier.addListener(_onEngineChanged);
    _schedulePackFiltersLoad();
    CatalogPackFiltersRegistry.revision.addListener(_onFilters);
    CatalogKitTopMenuRegistry.revision.addListener(_onFilters);
  }

  @override
  void didUpdateWidget(covariant PluginHubCatalogTopBar oldWidget) {
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
    if (found?.plugin.hasCapability(CatalogHubCapabilities.filters) == true) {
      await CatalogPackFiltersRegistry.ensureLoaded(pluginId);
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
    CatalogPackFiltersRegistry.invalidate(pluginId);
    unawaited(_loadPluginAndFilters(pluginId));
  }

  @override
  void dispose() {
    SettingsService.navbarChangeNotifier.removeListener(_onNavbarChanged);
    EngineService.changeNotifier.removeListener(_onEngineChanged);
    CatalogPackFiltersRegistry.revision.removeListener(_onFilters);
    CatalogKitTopMenuRegistry.revision.removeListener(_onFilters);
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
    if (CatalogKitTopMenuRegistry.hasTopMenu(widget.tabId)) {
      return CatalogKitTopBar(tabId: widget.tabId);
    }
    return _buildBrowseTopBar(context);
  }

  Widget _buildBrowseTopBar(BuildContext context) {
    final pluginId = PluginNavRegistry.pluginIdForTabSync(widget.tabId);
    if (pluginId == null) return const SizedBox.shrink();
    final plugin = _pluginForTab;
    if (_layoutOnlyHub(plugin)) return const SizedBox.shrink();
    final canSearch =
        plugin?.hasCapability(CatalogHubCapabilities.search) ?? false;
    final canFilters =
        plugin?.hasCapability(CatalogHubCapabilities.filters) ?? false;
    final hasVerticalFilters =
        CatalogVerticalFiltersRegistry.specFor(widget.tabId) != null;
    if (!canSearch && !canFilters && !hasVerticalFilters) {
      return const SizedBox.shrink();
    }
    final label =
        PluginNavRegistry.destinations[widget.tabId]?.label ?? 'Search';
    final categories = CatalogPackFiltersRegistry.categoriesFor(pluginId);
    final menus = CatalogPackFiltersRegistry.menusFor(pluginId);
    final selectedMenu = ShellBus.hubSelectedMenuIdFor(widget.tabId);
    // Drop stale menu id when this pack no longer declares it.
    final currentMenu = selectedMenu.value;
    if (currentMenu != null &&
        CatalogPackFiltersRegistry.menuById(pluginId, currentMenu) == null) {
      selectedMenu.value = null;
    }
    return CatalogTopBar(
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
                openHubCatalogSearch(
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
