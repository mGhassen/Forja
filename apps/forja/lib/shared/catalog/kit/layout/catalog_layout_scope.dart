import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'catalog_kit_types.dart';

export 'catalog_kit_types.dart'
    show
        catalogKitItemsFromSpec,
        initLayoutTabSelections,
        layoutWidgetSpecIndex,
        walkLayoutWidgets;

/// Pack layout selections (`kit.menu` / `kit.tabs`) scoped to one shell tab.
class CatalogLayoutScope extends InheritedWidget {
  const CatalogLayoutScope({
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

  static CatalogLayoutScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CatalogLayoutScope>();
  }

  static CatalogLayoutScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'CatalogLayoutScope not found');
    return scope!;
  }

  String? selectedId(String widgetId) {
    final value = selections[widgetId];
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Map<String, dynamic>? widgetSpecFor(String widgetId) => widgetSpecs[widgetId];

  @override
  bool updateShouldNotify(CatalogLayoutScope oldWidget) {
    return !mapEquals(selections, oldWidget.selections) ||
        !mapEquals(widgetSpecs, oldWidget.widgetSpecs);
  }
}

/// @deprecated Use [catalogKitItemsFromSpec].
List<({String id, String label})> catalogLayoutTabsFromSpec(
  Map<String, dynamic> spec,
) => catalogKitItemsFromSpec(spec);
