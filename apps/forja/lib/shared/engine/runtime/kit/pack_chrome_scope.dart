import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Host chrome state for one pack layout tab (search query, refresh, view, dynamic bars).
///
/// Selections for menus/tabs stay on [LayoutScope]; this holds feed-affecting extras
/// and dynamic category bar items derived from the last feed.
class PackChromeScope extends InheritedWidget {
  const PackChromeScope({
    super.key,
    required this.eventQuery,
    required this.refreshEpoch,
    required this.viewStyle,
    required this.dynamicBarItems,
    required this.selectedListItem,
    required this.onEventQuery,
    required this.onBumpRefresh,
    required this.onViewStyle,
    required this.onDynamicBarItems,
    required this.onSelectListItem,
    required super.child,
  });

  final String eventQuery;
  final int refreshEpoch;
  final String viewStyle;
  final Map<String, List<Map<String, dynamic>>> dynamicBarItems;
  final Map<String, dynamic>? selectedListItem;

  final void Function(String query) onEventQuery;
  final VoidCallback onBumpRefresh;
  final void Function(String style) onViewStyle;
  final void Function(String barId, List<Map<String, dynamic>> items)
      onDynamicBarItems;
  final void Function(Map<String, dynamic>? item) onSelectListItem;

  static PackChromeScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PackChromeScope>();
  }

  static PackChromeScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'PackChromeScope not found');
    return scope!;
  }

  List<Map<String, dynamic>>? barItems(String barId) {
    final id = barId.trim();
    if (id.isEmpty) return null;
    return dynamicBarItems[id];
  }

  @override
  bool updateShouldNotify(PackChromeScope oldWidget) {
    return eventQuery != oldWidget.eventQuery ||
        refreshEpoch != oldWidget.refreshEpoch ||
        viewStyle != oldWidget.viewStyle ||
        selectedListItem != oldWidget.selectedListItem ||
        !mapEquals(dynamicBarItems, oldWidget.dynamicBarItems);
  }
}
