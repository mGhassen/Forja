import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/layout_scope.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/chrome/underline_tab.dart';

/// Layout widget [`LayoutTypes.menu`] — underline kind/filter menu.
///
/// Default paint is [ForjaUnderlineTab]. Host may inject TV chrome via
/// [tabBuilder] / [wrapRow].
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
    final useTv = ShellPaintScope.useTvFocusOf(context);
    final gap = tabGap ??
        (useTv
            ? ShellTokens.kitTopBarTabGapTv
            : MediaQuery.sizeOf(context).width <
                    ShellTokens.kitTopBarTabGapCompactMaxWidth
                ? ShellTokens.kitTopBarTabGapCompact
                : ShellTokens.kitTopBarTabGapWide);
    final tabId = (scope.tabId ?? ShellPaintTvTabScope.tabIdOf(context) ?? '')
        .trim();
    final focusDown = scope.resolveFocusEdge(spec['focusDown']?.toString());
    final focusLeft = scope.resolveFocusEdge(spec['focusLeft']?.toString());
    final focusRight = scope.resolveFocusEdge(
      spec['focusRight']?.toString(),
      last: true,
    );
    final focusUp = scope.resolveFocusEdge(
      spec['focusUp']?.toString(),
      last: true,
    );

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
              tvFocus: useTv && tabId.isNotEmpty,
              tabId: tabId,
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

    Widget out = padded;
    if (useTv && tabId.isNotEmpty && wrapRow == null) {
      out = ShellPaintScope.tvRow(
        context: context,
        tabId: tabId,
        rowId: _widgetId,
        sortOrder: 0,
        itemCount: _items.length,
        onFocusUp: focusUp,
        onFocusDown: focusDown,
        child: padded,
      );
    } else if (wrapRow != null) {
      out = wrapRow!(padded);
    }
    return out;
  }
}
