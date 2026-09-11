import 'package:flutter/material.dart';
import 'package:forja/shared/shell/focus_edge.dart';
import 'package:forja/shared/shell/forja_status_tabs.dart';
import 'package:forja_foundation/widgets/chrome/catalog_tabs.dart';

export 'package:forja_foundation/widgets/chrome/catalog_tabs.dart'
    show CatalogTabs;

/// Host TV wrapper over [CatalogTabs].
class KitTabsWidget extends StatelessWidget {
  const KitTabsWidget({
    super.key,
    required this.tabId,
    required this.spec,
    this.sortOrder = 0,
    this.inShellTopBar = false,
  });

  final String tabId;
  final Map<String, dynamic> spec;
  final int sortOrder;
  final bool inShellTopBar;

  @override
  Widget build(BuildContext context) {
    return CatalogTabs(
      spec: spec,
      inShellTopBar: inShellTopBar,
      tabsBuilder: ({
        required widgetId,
        required items,
        required selected,
        required onSelect,
      }) {
        return ForjaStatusTabs(
          tabId: tabId,
          rowId: widgetId,
          sortOrder: sortOrder,
          tabs: [
            for (final tab in items) (id: tab.id, title: tab.label),
          ],
          selected: selected,
          onSelect: onSelect,
          onUp: kitFocusEdge(tabId, spec['focusUp']?.toString(), last: true),
          onDown: kitFocusEdge(tabId, spec['focusDown']?.toString()),
          onLeft: kitFocusSide(tabId, spec['focusLeft']),
          onRight: kitFocusSide(tabId, spec['focusRight']),
          inShellTopBar: inShellTopBar,
        );
      },
    );
  }
}
