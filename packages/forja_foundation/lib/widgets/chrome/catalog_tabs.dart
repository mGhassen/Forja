import 'package:flutter/material.dart';
import 'package:forja_foundation/widgets/chrome/layout_scope.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/chrome/status_tabs.dart';

/// Layout widget [`LayoutTypes.tabs`] — equal-width status / segment strip.
///
/// Default paint is [ForjaStatusTabs]. Host may inject via [tabsBuilder].
class CatalogTabs extends StatelessWidget {
  const CatalogTabs({
    super.key,
    required this.spec,
    this.inShellTopBar = false,
    this.tabsBuilder,
    this.wrapRow,
  });

  final Map<String, dynamic> spec;
  final bool inShellTopBar;

  /// Host builds custom status chrome. Receives items + selection.
  final Widget Function({
    required String widgetId,
    required List<({String id, String label})> items,
    required String selected,
    required ValueChanged<String> onSelect,
  })? tabsBuilder;

  final Widget Function(Widget child)? wrapRow;

  String get _widgetId => (spec['id'] ?? 'tabs').toString();
  List<({String id, String label})> get _items => layoutItemsFromSpec(spec);

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    final scope = LayoutScope.of(context);
    final selected = scope.selectedId(_widgetId) ??
        spec['default']?.toString() ??
        _items.first.id;
    final tabId = (scope.tabId ?? ShellPaintTvTabScope.tabIdOf(context) ?? '')
        .trim();

    void onSelect(String id) => scope.onSelect(_widgetId, id, toggle: false);

    final builder = tabsBuilder;
    Widget child;
    if (builder != null) {
      child = builder(
        widgetId: _widgetId,
        items: _items,
        selected: selected,
        onSelect: onSelect,
      );
    } else {
      child = ForjaStatusTabs(
        tabId: tabId.isEmpty ? 'page' : tabId,
        rowId: _widgetId,
        sortOrder: 1,
        tabs: [
          for (final tab in _items) (id: tab.id, title: tab.label),
        ],
        selected: selected,
        onSelect: onSelect,
        onUp: scope.resolveFocusEdge(spec['focusUp']?.toString(), last: true),
        onDown: scope.resolveFocusEdge(spec['focusDown']?.toString()),
        onLeft: scope.resolveFocusEdge(spec['focusLeft']?.toString()),
        onRight: scope.resolveFocusEdge(
          spec['focusRight']?.toString(),
          last: true,
        ),
        inShellTopBar: inShellTopBar,
      );
    }

    final wrap = wrapRow;
    return wrap == null ? child : wrap(child);
  }
}
