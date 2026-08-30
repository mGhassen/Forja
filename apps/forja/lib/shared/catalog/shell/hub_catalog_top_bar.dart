import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/catalog/kit/chrome/catalog_pack_filters.dart';
import 'package:forja/shared/catalog/plugin_nav.dart';
import 'package:forja/shared/catalog/shell/catalog_search_screen.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shell/catalog_top_bar.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';

void openHubCatalogSearch(
  BuildContext context, {
  required String pluginId,
  required String tabId,
  required String hintText,
}) {
  pushShellRoute(
    context,
    AppRouter.slideShellRoute(
      (_) => CatalogSearchScreen(
        pluginId: pluginId,
        tabId: tabId,
        hintText: hintText,
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
  @override
  void initState() {
    super.initState();
    final pluginId = PluginNavRegistry.pluginIdForTabSync(widget.tabId);
    if (pluginId != null) {
      unawaited(CatalogPackFiltersRegistry.ensureLoaded(pluginId));
    }
    CatalogPackFiltersRegistry.revision.addListener(_onFilters);
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
    final label = PluginNavRegistry.destinations[widget.tabId]?.label ?? 'Search';
    final categories = CatalogPackFiltersRegistry.categoriesFor(pluginId);
    return CatalogTopBar(
      tabId: widget.tabId,
      seriesLabel: 'Series',
      mediaCategory: ShellBus.hubCategoryFor(widget.tabId),
      selectedCategoryId: ShellBus.hubSelectedCategoryIdFor(widget.tabId),
      categories: categories,
      scrollOffset: ShellBus.hubScrollOffsetFor(widget.tabId),
      heroHeight: ShellBus.hubHeroHeightFor(widget.tabId),
      onSearch: () => openHubCatalogSearch(
        context,
        pluginId: pluginId,
        tabId: widget.tabId,
        hintText: 'Search $label…',
      ),
    );
  }
}
