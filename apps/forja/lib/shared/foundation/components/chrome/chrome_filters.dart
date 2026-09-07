import 'package:flutter/foundation.dart';
import 'package:forja/shared/foundation/components/chrome/pack_filters.dart';
import 'package:forja/shared/foundation/components/chrome/vertical_filters.dart';
import 'package:forja/shared/foundation/services/plugin_nav.dart';
import 'package:forja/shell/bus/shell_bus.dart';

/// Shell top-bar + pack `filters` → protocol filter leaves (plugin-driven).
List<Map<String, dynamic>?> catalogChromeFilters({
  required String? tabId,
  String? pluginId,
}) {
  if (tabId == null) return const [];
  final pid = pluginId ?? PluginNavRegistry.pluginIdForTabSync(tabId);
  if (pid == null) return const [];
  return [
    ...PackFiltersRegistry.activeFilters(pluginId: pid, tabId: tabId),
    VerticalFiltersRegistry.activeFilterFor(tabId),
  ];
}

String catalogChromeFilterEpoch(String? tabId) {
  final vertical = VerticalFiltersRegistry.chromeFilterEpoch(tabId);
  if (tabId == null) return vertical;
  final menu = ShellBus.hubSelectedMenuIdFor(tabId).value;
  final cat = ShellBus.hubSelectedCategoryIdFor(tabId).value;
  return '$menu|$cat|$vertical';
}

Listenable? catalogChromeFilterListenable(String? tabId) {
  final id = tabId?.trim();
  if (id == null || id.isEmpty) return null;
  // Value notifiers only — pack/vertical `revision` bumps on first load and
  // layout sync must not invalidate painted rails when filters are unchanged.
  return Listenable.merge([
    ShellBus.hubSelectedMenuIdFor(id),
    ShellBus.hubSelectedCategoryIdFor(id),
    VerticalFiltersRegistry.selectedIdFor(id),
  ]);
}

/// Layout `hideWhenTypeFilter` — hide when a pack menu with
/// `hideTypeFilterRails` is selected (not Categories / vertical filters).
bool catalogChromeHidesTypeFilterRails(String? tabId) {
  if (tabId == null) return false;
  final pluginId = PluginNavRegistry.pluginIdForTabSync(tabId);
  if (pluginId == null) {
    return ShellBus.hubSelectedMenuIdFor(tabId).value != null;
  }
  return PackFiltersRegistry.selectedMenuHidesTypeFilterRails(
    pluginId: pluginId,
    tabId: tabId,
  );
}
