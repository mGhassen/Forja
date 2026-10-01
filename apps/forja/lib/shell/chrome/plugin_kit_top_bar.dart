import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/engine/runtime/nav/open_catalog_search.dart';
import 'package:forja/shared/engine/runtime/kit/hub_menu_clearance.dart';
import 'package:forja/shared/engine/runtime/nav/pack_filters.dart';
import 'package:forja/shared/engine/runtime/nav/plugin_nav.dart';
import 'package:forja/shared/engine/runtime/nav/vertical_filters.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:forja/shell/chrome/kit_chrome_top_bar.dart';
import 'package:forja_foundation/protocol/pack_capabilities.dart';
import 'package:rust/rust.dart' show SettingsService;

/// Shell top chrome for pack hubs — Search + pack filter menus/categories.
///
/// Layout-only hubs paint their own composition chrome in-body.
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
    PackFiltersRegistry.revision.addListener(_onFilters);
    _schedulePackFiltersLoad();
  }

  @override
  void didUpdateWidget(covariant PluginKitTopBar oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    super.dispose();
  }

  void _onFilters() {
    if (mounted) setState(() {});
  }

  EnginePlugin? get _pluginForTab {
    final pluginId = PluginNavRegistry.pluginIdForTabSync(widget.tabId);
    if (pluginId == null || _plugin == null) return null;
    return _plugin!.id == pluginId ? _plugin : null;
  }

  @override
  Widget build(BuildContext context) {
    final pluginId = PluginNavRegistry.pluginIdForTabSync(widget.tabId);
    if (pluginId == null) return const SizedBox.shrink();
    final plugin = _pluginForTab;
    final hasVerticalFilters =
        VerticalFiltersRegistry.specFor(widget.tabId) != null;
    if (!hubShellTopBarVisible(
      plugin,
      hasVerticalFilters: hasVerticalFilters,
    )) {
      return const SizedBox.shrink();
    }
    final canSearch =
        plugin?.hasCapability(PackCapabilities.search) ?? false;
    final label =
        PluginNavRegistry.destinations[widget.tabId]?.label ?? 'Search';
    final categories = PackFiltersRegistry.categoriesFor(pluginId);
    final menus = PackFiltersRegistry.menusFor(pluginId);
    final selectedMenu = ShellBus.hubSelectedMenuIdFor(widget.tabId);
    final currentMenu = selectedMenu.value;
    if (currentMenu != null &&
        PackFiltersRegistry.menuById(pluginId, currentMenu) == null) {
      selectedMenu.value = null;
    }
    return ValueListenableBuilder<bool>(
      valueListenable: ShellBus.hubLayoutRtlFor(widget.tabId),
      builder: (context, rtl, child) {
        return Directionality(
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          child: child!,
        );
      },
      child: KitChromeTopBar(
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
                openCatalogSearch(
                  context,
                  pluginId: pluginId,
                  tabId: widget.tabId,
                  hintText: 'Search $label…',
                ),
              );
            }
          : null,
      ),
    );
  }
}
