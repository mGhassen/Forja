import 'package:flutter/material.dart';
import 'package:forja/shared/catalog/kit/chrome/catalog_status_tabs.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_kit_focus.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_layout_scope.dart';

/// Layout widget [`CatalogKitTypes.tabs`] — equal-width status / segment strip.
class CatalogKitTabsWidget extends StatelessWidget {
  const CatalogKitTabsWidget({
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

  String get _widgetId => (spec['id'] ?? 'tabs').toString();
  List<({String id, String label})> get _items => catalogKitItemsFromSpec(spec);

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    final scope = CatalogLayoutScope.of(context);
    final selected = scope.selectedId(_widgetId);
    final statusTabs = [
      for (final tab in _items) (id: tab.id, title: tab.label),
    ];
    return CatalogStatusTabs(
      tabId: tabId,
      rowId: _widgetId,
      sortOrder: sortOrder,
      tabs: statusTabs,
      selected: selected ?? spec['default']?.toString() ?? _items.first.id,
      onSelect: (id) => scope.onSelect(_widgetId, id, toggle: false),
      onUp: catalogKitFocusEdge(tabId, spec['focusUp']?.toString(), last: true),
      onDown: catalogKitFocusEdge(tabId, spec['focusDown']?.toString()),
      inShellTopBar: inShellTopBar,
    );
  }
}
