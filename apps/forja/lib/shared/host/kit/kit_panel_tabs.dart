import 'package:flutter/material.dart';
import 'package:forja_foundation/kit/kit_types.dart';

/// One sources-panel tab from pack `kit.list.panelTabs`.
class KitPanelTabSpec {
  const KitPanelTabSpec({
    required this.id,
    required this.label,
    this.icon = '',
    this.browse = false,
  });

  final String id;
  final String label;
  final String icon;
  final bool browse;
}

List<KitPanelTabSpec> kitPanelTabsFromSpec(Map<String, dynamic> spec) {
  final raw = spec['panelTabs'];
  if (raw is! List) return const [];
  final out = <KitPanelTabSpec>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final id = (item['id'] ?? '').toString().trim();
    if (id.isEmpty) continue;
    final label = (item['label'] ?? item['title'] ?? id).toString().trim();
    out.add(
      KitPanelTabSpec(
        id: id,
        label: label.isEmpty ? id : label,
        icon: (item['icon'] ?? '').toString().trim(),
        browse: item['browse'] == true,
      ),
    );
  }
  return out;
}

String? kitPanelDefaultTabId(
  Map<String, dynamic> spec,
  List<KitPanelTabSpec> tabs,
) {
  final d = (spec['panelTab'] ?? spec['defaultTab'] ?? '').toString().trim();
  if (d.isNotEmpty) return d;
  return tabs.isEmpty ? null : tabs.first.id;
}

/// First `kit.list` in [widgets] that declares `panelTabs`.
({List<KitPanelTabSpec> tabs, String? initial}) kitPanelChromeFromLayouts(
  List<Map<String, dynamic>> widgets,
) {
  var tabs = const <KitPanelTabSpec>[];
  String? initial;
  walkKitWidgets(widgets, (spec) {
    if (tabs.isNotEmpty) return;
    final type = KitTypes.normalize((spec['type'] ?? '').toString(), spec);
    if (type != KitTypes.list) return;
    final parsed = kitPanelTabsFromSpec(spec);
    if (parsed.isEmpty) return;
    tabs = parsed;
    initial = kitPanelDefaultTabId(spec, parsed);
  });
  return (tabs: tabs, initial: initial);
}

Set<String> kitPanelBrowseTabIds(List<KitPanelTabSpec> tabs) => {
      for (final t in tabs)
        if (t.browse) t.id,
    };

IconData kitPanelTabIcon(String token) {
  return switch (token.trim().toLowerCase()) {
    'dns' => Icons.dns_rounded,
    'tv' => Icons.live_tv_rounded,
    'search' => Icons.search_rounded,
    _ => Icons.list_alt_rounded,
  };
}
