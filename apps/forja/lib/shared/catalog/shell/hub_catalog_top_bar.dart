import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/catalog/catalog_hub_capabilities.dart';
import 'package:forja/shared/catalog/kit/chrome/catalog_pack_filters.dart';
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

  @override
  Widget build(BuildContext context) {
    final pluginId = PluginNavRegistry.pluginIdForTabSync(widget.tabId);
    if (pluginId == null) return const SizedBox.shrink();
    final plugin = _plugin;
    final label =
        PluginNavRegistry.destinations[widget.tabId]?.label ?? 'Search';
    final categories = CatalogPackFiltersRegistry.categoriesFor(pluginId);
    final canSearch =
        plugin?.hasCapability(CatalogHubCapabilities.search) ?? false;
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
