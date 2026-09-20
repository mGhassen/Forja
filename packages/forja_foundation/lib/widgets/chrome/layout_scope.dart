import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:forja_foundation/protocol/layout_types.dart';

export 'package:forja_foundation/protocol/layout_types.dart'
    show
        layoutItemsFromSpec,
        initLayoutTabSelections,
        layoutWidgetSpecIndex,
        walkLayoutWidgets;

/// Pack layout selections (`kit.menu` / `kit.tabs`) scoped to one shell tab.
class LayoutScope extends InheritedWidget {
  const LayoutScope({
    super.key,
    required this.selections,
    required this.onSelect,
    required this.widgetSpecs,
    this.tabId,
    this.focusEdge,
    required super.child,
  });

  final Map<String, String> selections;
  final void Function(String widgetId, String value, {required bool toggle})
  onSelect;
  final Map<String, Map<String, dynamic>> widgetSpecs;

  /// Shell nav / TV tab id for focus graph rows.
  final String? tabId;

  /// Host resolves pack `focusUp` / `focusDown` / side edges to callbacks.
  ///
  /// [last] → remembered index; [lastItem] → final index on the row.
  final VoidCallback? Function(
    String? rowId, {
    bool last,
    bool lastItem,
  })? focusEdge;

  static LayoutScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<LayoutScope>();
  }

  static LayoutScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'LayoutScope not found');
    return scope!;
  }

  String? selectedId(String widgetId) {
    final value = selections[widgetId];
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Map<String, dynamic>? widgetSpecFor(String widgetId) => widgetSpecs[widgetId];

  VoidCallback? resolveFocusEdge(
    String? rowId, {
    bool last = false,
    bool lastItem = false,
  }) {
    final edge = focusEdge;
    if (edge == null || rowId == null || rowId.isEmpty) return null;
    return edge(rowId, last: last, lastItem: lastItem);
  }

  @override
  bool updateShouldNotify(LayoutScope oldWidget) {
    // Do not compare [focusEdge] — parent rebuilds pass a new closure every
    // time; that forced every LayoutScope dependent to rebuild on any setState.
    return !mapEquals(selections, oldWidget.selections) ||
        !mapEquals(widgetSpecs, oldWidget.widgetSpecs) ||
        tabId != oldWidget.tabId;
  }
}

/// @deprecated Use [layoutItemsFromSpec].
List<({String id, String label})> catalogLayoutTabsFromSpec(
  Map<String, dynamic> spec,
) => layoutItemsFromSpec(spec);
