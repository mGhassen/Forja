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
    required super.child,
  });

  final Map<String, String> selections;
  final void Function(String widgetId, String value, {required bool toggle})
  onSelect;
  final Map<String, Map<String, dynamic>> widgetSpecs;

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

  @override
  bool updateShouldNotify(LayoutScope oldWidget) {
    return !mapEquals(selections, oldWidget.selections) ||
        !mapEquals(widgetSpecs, oldWidget.widgetSpecs);
  }
}

/// @deprecated Use [layoutItemsFromSpec].
List<({String id, String label})> catalogLayoutTabsFromSpec(
  Map<String, dynamic> spec,
) => layoutItemsFromSpec(spec);
