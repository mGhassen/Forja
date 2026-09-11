import 'package:flutter/material.dart';
import 'package:forja_foundation/components/tabs.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/layout_scope.dart';

/// Layout widget [`LayoutTypes.menu`] — underline kind/filter menu (Zone A).
///
/// Host injects TV underline tabs via [tabBuilder] / [wrapRow].
class CatalogMenu extends StatelessWidget {
  const CatalogMenu({
    super.key,
    required this.spec,
    this.count,
    this.firstFocusNode,
    this.inShellTopBar = false,
    this.tabGap,
    this.tabBuilder,
    this.wrapRow,
  });

  final Map<String, dynamic> spec;
  final int? count;
  final FocusNode? firstFocusNode;
  final bool inShellTopBar;

  /// Override default gap (TV / compact).
  final double? tabGap;

  final Widget Function({
    required int index,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    FocusNode? focusNode,
  })? tabBuilder;

  final Widget Function(Widget child)? wrapRow;

  String get _widgetId => (spec['id'] ?? 'menu').toString();
  bool get _toggle => spec['toggle'] == true;
  List<({String id, String label})> get _items => layoutItemsFromSpec(spec);

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    final scope = LayoutScope.of(context);
    final selected = scope.selectedId(_widgetId);
    final gap = tabGap ??
        (MediaQuery.sizeOf(context).width < 560 ? 20.0 : 36.0);

    final customTab = tabBuilder;
    late final Widget row;
    if (customTab != null) {
      row = Row(
        children: [
          for (var i = 0; i < _items.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            customTab(
              index: i,
              label: _items[i].label,
              isActive: selected == _items[i].id,
              onTap: () => scope.onSelect(
                _widgetId,
                _items[i].id,
                toggle: _toggle,
              ),
              focusNode: i == 0 ? firstFocusNode : null,
            ),
          ],
          const Spacer(),
          if (count != null && count! > 0)
            Text(
              '$count',
              style: const TextStyle(color: Colors.white38, fontSize: 14),
            ),
        ],
      );
    } else {
      final selectedIndex = selected == null
          ? 0
          : _items
              .indexWhere((t) => t.id == selected)
              .clamp(0, _items.length - 1);
      row = Row(
        children: [
          Expanded(
            child: UnderlineTabBar(
              labels: [for (final t in _items) t.label],
              selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
              onChanged: (i) => scope.onSelect(
                _widgetId,
                _items[i].id,
                toggle: _toggle,
              ),
            ),
          ),
          if (count != null && count! > 0)
            Text(
              '$count',
              style: const TextStyle(color: Colors.white38, fontSize: 14),
            ),
        ],
      );
    }

    final padded = Padding(
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
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: row,
      ),
    );

    final wrap = wrapRow;
    return wrap == null ? padded : wrap(padded);
  }
}
