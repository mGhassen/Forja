import 'package:flutter/material.dart';
import 'package:forja/shared/shell/kit_focus.dart';
import 'package:forja/shared/kit/kit_layout_scope.dart';
import 'package:forja/shared/shell/forja_status_tabs.dart';

/// Layout widget [`KitTypes.tabs`] — equal-width status / segment strip.
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

  String get _widgetId => (spec['id'] ?? 'tabs').toString();
  List<({String id, String label})> get _items => kitItemsFromSpec(spec);

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    final scope = KitLayoutScope.of(context);
    final selected = scope.selectedId(_widgetId);
    final statusTabs = [
      for (final tab in _items) (id: tab.id, title: tab.label),
    ];
    return ForjaStatusTabs(
      tabId: tabId,
      rowId: _widgetId,
      sortOrder: sortOrder,
      tabs: statusTabs,
      selected: selected ?? spec['default']?.toString() ?? _items.first.id,
      onSelect: (id) => scope.onSelect(_widgetId, id, toggle: false),
      onUp: kitFocusEdge(tabId, spec['focusUp']?.toString(), last: true),
      onDown: kitFocusEdge(tabId, spec['focusDown']?.toString()),
      onLeft: kitFocusSide(tabId, spec['focusLeft']),
      onRight: kitFocusSide(tabId, spec['focusRight']),
      inShellTopBar: inShellTopBar,
    );
  }
}
