import 'package:flutter/material.dart';
import 'package:forja_foundation/components/tabs.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/layout_scope.dart';

/// Layout widget [`LayoutTypes.tabs`] — equal-width status / segment strip.
///
/// Host injects TV status tabs via [tabsBuilder]; default uses [UnderlineTabBar].
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
