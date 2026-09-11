import 'package:flutter/material.dart';
import 'package:forja_foundation/protocol/layout_types.dart';

/// One sources-panel tab from pack `kit.list.panelTabs`.
class PanelTabSpec {
  const PanelTabSpec({
    required this.id,
    required this.label,
    this.icon = '',
    this.browse = false,
    this.action = '',
  });

  final String id;
  final String label;
  final String icon;
  final bool browse;

  /// MetaRuntime / loader key. Empty → [id].
  final String action;
}

List<PanelTabSpec> panelTabsFromSpec(Map<String, dynamic> spec) {
  final raw = spec['panelTabs'];
  if (raw is! List) return const [];
  final out = <PanelTabSpec>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final id = (item['id'] ?? '').toString().trim();
    if (id.isEmpty) continue;
    final label = (item['label'] ?? item['title'] ?? id).toString().trim();
    out.add(
      PanelTabSpec(
        id: id,
        label: label.isEmpty ? id : label,
        icon: (item['icon'] ?? '').toString().trim(),
        browse: item['browse'] == true,
        action: (item['action'] ?? '').toString().trim(),
      ),
    );
  }
  return out;
}

String? panelDefaultTabId(
  Map<String, dynamic> spec,
  List<PanelTabSpec> tabs,
) {
  final d = (spec['panelTab'] ?? spec['defaultTab'] ?? '').toString().trim();
  if (d.isNotEmpty) return d;
  return tabs.isEmpty ? null : tabs.first.id;
}

/// First `kit.list` in [widgets] that declares `panelTabs`.
({List<PanelTabSpec> tabs, String? initial}) panelChromeFromLayouts(
  List<Map<String, dynamic>> widgets,
) {
  var tabs = const <PanelTabSpec>[];
  String? initial;
  walkLayoutWidgets(widgets, (spec) {
    if (tabs.isNotEmpty) return;
    final type = LayoutTypes.normalize((spec['type'] ?? '').toString(), spec);
    if (type != LayoutTypes.list) return;
    final parsed = panelTabsFromSpec(spec);
    if (parsed.isEmpty) return;
    tabs = parsed;
    initial = panelDefaultTabId(spec, parsed);
  });
  return (tabs: tabs, initial: initial);
}

Set<String> panelBrowseTabIds(List<PanelTabSpec> tabs) => {
      for (final t in tabs)
        if (t.browse) t.id,
    };

/// Loader key for [tabId] — pack `action` if set, else the chrome id.
String panelTabLoadId(List<PanelTabSpec> tabs, String tabId) {
  for (final t in tabs) {
    if (t.id == tabId) {
      return t.action.isNotEmpty ? t.action : t.id;
    }
  }
  return tabId;
}

IconData kitPanelTabIcon(String token) {
  return switch (token.trim().toLowerCase()) {
    'dns' => Icons.dns_rounded,
    'tv' => Icons.live_tv_rounded,
    'search' => Icons.search_rounded,
    _ => Icons.list_alt_rounded,
  };
}
