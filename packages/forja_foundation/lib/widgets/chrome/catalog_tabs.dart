import 'package:flutter/material.dart';
import 'package:forja_foundation/components/tabs.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/layout_scope.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/chrome/status_tabs.dart';

/// Layout widget [`LayoutTypes.tabs`] — equal-width status / segment strip.
///
/// When [ShellPaintScope.useTvFocusOf] and no [tabsBuilder], uses [ForjaStatusTabs].
class CatalogTabs extends StatelessWidget {
  const CatalogTabs({
    super.key,
    required this.spec,
    this.inShellTopBar = false,
    this.sortOrder = 0,
    this.tabsBuilder,
    this.wrapRow,
  });

  final Map<String, dynamic> spec;
  final bool inShellTopBar;
  final int sortOrder;

  /// Host builds ForjaStatusTabs / TV chrome. Receives items + selection.
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
    final selected =
        scope.selectedId(_widgetId) ??
        spec['default']?.toString() ??
        _items.first.id;

    void onSelect(String id) =>
        scope.onSelect(_widgetId, id, toggle: false);

    final builder = tabsBuilder;
    Widget child;
    if (builder != null) {
      child = builder(
        widgetId: _widgetId,
        items: _items,
        selected: selected,
        onSelect: onSelect,
      );
    } else if (ShellPaintScope.useTvFocusOf(context) &&
        (scope.tabId != null && scope.tabId!.isNotEmpty)) {
      child = ForjaStatusTabs(
        tabId: scope.tabId!,
        rowId: _widgetId,
        sortOrder: sortOrder,
        tabs: [for (final tab in _items) (id: tab.id, title: tab.label)],
        selected: selected,
        onSelect: onSelect,
        onUp: scope.resolveFocusEdge(
          spec['focusUp']?.toString(),
          last: true,
        ),
        onDown: scope.resolveFocusEdge(spec['focusDown']?.toString()),
        onLeft: scope.resolveFocusEdge(
          spec['focusLeft']?.toString(),
          last: true,
        ),
        onRight: scope.resolveFocusEdge(
          spec['focusRight']?.toString(),
          last: true,
        ),
        inShellTopBar: inShellTopBar,
      );
    } else {
      final selectedIndex =
          _items.indexWhere((t) => t.id == selected).clamp(0, _items.length - 1);
      child = Padding(
        padding: EdgeInsets.fromLTRB(
          inShellTopBar
              ? ShellTokens.shellTopBarMenuLeadingInset(context)
              : ShellTokens.compactChromeLeadingInset(context),
          inShellTopBar
              ? ShellTokens.shellHeaderTopPadding
              : ShellTokens.tabHeaderTopPadding,
          ShellTokens.bodyHorizontalPadding,
          inShellTopBar ? 0 : 4,
        ),
        child: UnderlineTabBar(
          labels: [for (final t in _items) t.label],
          selectedIndex: selectedIndex,
          onChanged: (i) => onSelect(_items[i].id),
        ),
      );
    }

    final wrap = wrapRow;
    return wrap == null ? child : wrap(child);
  }
}
