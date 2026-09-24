import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/runtime/nav/pack_filters.dart';
import 'package:forja/shared/engine/runtime/nav/vertical_filters.dart';
import 'package:forja/shared/engine/runtime/nav/plugin_nav.dart';
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

/// Active chrome `type` filter value (`movie` / `tv` / `anime` / …), or null.
///
/// Used with layout `showWhenType` so packs can hide rails that do not match
/// the selected top-menu type without host product branches.
String? catalogChromeTypeFilterValue({
  required String? tabId,
  String? pluginId,
}) {
  for (final raw in catalogChromeFilters(tabId: tabId, pluginId: pluginId)) {
    final v = _filterEqValue(raw, 'type');
    if (v != null && v.isNotEmpty) return v;
  }
  return null;
}

String? _filterEqValue(Map<String, dynamic>? filter, String field) {
  if (filter == null) return null;
  final op = (filter['op'] ?? '').toString();
  if (op == 'and' || op == 'or') {
    final nodes = filter['nodes'];
    if (nodes is! List) return null;
    for (final n in nodes) {
      if (n is! Map) continue;
      final hit = _filterEqValue(Map<String, dynamic>.from(n), field);
      if (hit != null) return hit;
    }
    return null;
  }
  if ((filter['field'] ?? '').toString() != field) return null;
  if (op == 'eq' || op.isEmpty) {
    final v = filter['value'] ?? filter['values'];
    if (v is List && v.isNotEmpty) return v.first.toString().trim();
    return v?.toString().trim();
  }
  return null;
}
