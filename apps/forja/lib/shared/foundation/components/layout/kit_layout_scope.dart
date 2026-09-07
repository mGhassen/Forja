import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'kit_types.dart';

export 'kit_types.dart'
    show
        kitItemsFromSpec,
        initKitTabSelections,
        kitWidgetSpecIndex,
        walkKitWidgets;

/// Pack layout selections (`kit.menu` / `kit.tabs`) scoped to one shell tab.
class KitLayoutScope extends InheritedWidget {
  const KitLayoutScope({
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

  static KitLayoutScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<KitLayoutScope>();
  }

  static KitLayoutScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'KitLayoutScope not found');
    return scope!;
  }

  String? selectedId(String widgetId) {
    final value = selections[widgetId];
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Map<String, dynamic>? widgetSpecFor(String widgetId) => widgetSpecs[widgetId];

  @override
  bool updateShouldNotify(KitLayoutScope oldWidget) {
    return !mapEquals(selections, oldWidget.selections) ||
        !mapEquals(widgetSpecs, oldWidget.widgetSpecs);
  }
}

/// @deprecated Use [kitItemsFromSpec].
List<({String id, String label})> catalogLayoutTabsFromSpec(
  Map<String, dynamic> spec,
) => kitItemsFromSpec(spec);
