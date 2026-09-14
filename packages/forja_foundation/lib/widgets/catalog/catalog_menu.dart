import 'package:flutter/material.dart';
import 'package:forja_foundation/components/tabs.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/layout_scope.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/chrome/underline_tab.dart';

/// Layout widget [`LayoutTypes.menu`] — underline kind/filter menu (Zone A).
///
/// When [ShellPaintScope.useTvFocusOf] and no [tabBuilder], uses [ForjaUnderlineTab]
/// + [ShellPaintScope.tvRow].
class CatalogMenu extends StatelessWidget {
  const CatalogMenu({
    super.key,
    required this.spec,
    this.count,
    this.firstFocusNode,
    this.inShellTopBar = false,
    this.sortOrder = 0,
    this.tabGap,
    this.tabBuilder,
    this.wrapRow,
  });

  final Map<String, dynamic> spec;
  final int? count;
  final FocusNode? firstFocusNode;
  final bool inShellTopBar;
  final int sortOrder;

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
  bool get _toggle {
    final raw = spec['toggle'];
    return raw == true || raw == 1 || raw == 'true';
  }

  List<({String id, String label})> get _items => layoutItemsFromSpec(spec);

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    final scope = LayoutScope.of(context);
    final selected = scope.selectedId(_widgetId);
    final useTv = ShellPaintScope.useTvFocusOf(context) &&
        (scope.tabId != null && scope.tabId!.isNotEmpty);
    final gap = tabGap ??
        (useTv
            ? 28.0
            : MediaQuery.sizeOf(context).width < 560
                ? 20.0
                : 36.0);

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
    } else if (useTv) {
      final focusDown = scope.resolveFocusEdge(spec['focusDown']?.toString());
      final focusLeft = scope.resolveFocusEdge(
        spec['focusLeft']?.toString(),
        last: true,
      );
      final focusRight = scope.resolveFocusEdge(
        spec['focusRight']?.toString(),
        last: true,
      );
      row = Row(
        children: [
          for (var i = 0; i < _items.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            ForjaUnderlineTab(
              label: _items[i].label,
              isActive: selected == _items[i].id,
              onTap: () => scope.onSelect(
                _widgetId,
                _items[i].id,
                toggle: _toggle,
              ),
              tvFocus: true,
              tabId: scope.tabId!,
              rowId: _widgetId,
              listIndex: i,
              onDownEdge: focusDown ?? () {},
              onLeftEdge: i == 0 ? focusLeft : null,
              onRightEdge: i == _items.length - 1 ? focusRight : null,
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
      // No selection (toggle cleared) → -1 so no tab paints active.
      // Never snap to index 0 — that looked like Film stayed selected.
      final selectedIndex = selected == null
          ? -1
          : _items.indexWhere((t) => t.id == selected);
      row = Row(
        children: [
          Expanded(
            child: UnderlineTabBar(
              labels: [for (final t in _items) t.label],
              selectedIndex: selectedIndex,
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

    Widget child = padded;
    if (useTv && customTab == null) {
      child = ShellPaintScope.tvRow(
        context: context,
        tabId: scope.tabId!,
        rowId: _widgetId,
        sortOrder: sortOrder,
        itemCount: _items.length,
        onFocusUp: scope.resolveFocusEdge(
              spec['focusUp']?.toString(),
              last: true,
            ) ??
            () {},
        child: padded,
      );
    }

    final wrap = wrapRow;
    return wrap == null ? child : wrap(child);
  }
}
