import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/catalog/catalog_hub_capabilities.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_kit_layout_chrome.dart';
import 'package:forja/shared/catalog/kit/chrome/catalog_pack_filters.dart';
import 'package:forja/shared/catalog/kit/chrome/catalog_vertical_filters.dart';
import 'package:forja/shared/catalog/plugin_nav.dart';
import 'package:forja/shared/catalog/shell/catalog_search_screen.dart';
import 'package:forja/shared/engine/engine.dart';
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
    final pluginId = PluginNavRegistry.pluginIdForTabSync(widget.tabId);
    if (pluginId != null) {
      unawaited(CatalogPackFiltersRegistry.ensureLoaded(pluginId));
      unawaited(_loadPlugin(pluginId));
    }
    CatalogPackFiltersRegistry.revision.addListener(_onFilters);
  }

  Future<void> _loadPlugin(String pluginId) async {
    final found = await PluginRegistry.instance.findPlugin(pluginId);
    if (!mounted) return;
    setState(() => _plugin = found?.plugin);
  }

  @override
  void dispose() {
    CatalogPackFiltersRegistry.revision.removeListener(_onFilters);
    super.dispose();
  }

  void _onFilters() {
    if (mounted) setState(() {});
  }

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

  bool _hideTopBar() {
    if (CatalogKitLayoutChromeRegistry.packOwnsChrome(widget.tabId)) {
      return true;
    }
    return _layoutOnlyHub(_plugin);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CatalogKitLayoutChromeRegistry.revision,
      builder: (context, _) {
        if (_hideTopBar()) return const SizedBox.shrink();
        return _buildTopBar(context);
      },
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final pluginId = PluginNavRegistry.pluginIdForTabSync(widget.tabId);
    if (pluginId == null) return const SizedBox.shrink();
    final plugin = _plugin;
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
    return CatalogTopBar(
      tabId: widget.tabId,
      seriesLabel: 'Series',
      mediaCategory: ShellBus.hubCategoryFor(widget.tabId),
      selectedCategoryId: ShellBus.hubSelectedCategoryIdFor(widget.tabId),
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
