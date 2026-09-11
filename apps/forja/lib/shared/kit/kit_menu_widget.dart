import 'package:flutter/material.dart';
import 'package:forja/shared/shell/kit_focus.dart';
import 'package:forja/shared/kit/kit_layout_scope.dart';
import 'package:forja/shared/shell/forja_underline_tab.dart';
import 'package:forja/shared/shell/forja_shell_scope.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja/shared/shell/tv/tv_focus_graph.dart';

/// Layout widget [`KitTypes.menu`] — underline kind/filter menu.
class KitMenuWidget extends StatelessWidget {
  const KitMenuWidget({
    super.key,
    required this.tabId,
    required this.spec,
    this.sortOrder = 0,
    this.count,
    this.firstFocusNode,
    this.inShellTopBar = false,
  });

  final String tabId;
  final Map<String, dynamic> spec;
  final int sortOrder;
  final int? count;
  final FocusNode? firstFocusNode;
  final bool inShellTopBar;

  String get _widgetId => (spec['id'] ?? 'menu').toString();
  bool get _toggle => spec['toggle'] == true;
  List<({String id, String label})> get _items => kitItemsFromSpec(spec);

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    final scope = KitLayoutScope.of(context);
    final selected = scope.selectedId(_widgetId);
    final focusUp = kitFocusEdge(
      tabId,
      spec['focusUp']?.toString(),
      last: true,
    );
    final focusDown = kitFocusEdge(tabId, spec['focusDown']?.toString());
    final focusLeft = kitFocusSide(tabId, spec['focusLeft']);
    final focusRight = kitFocusSide(tabId, spec['focusRight']);

    final useTv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final tabGap = useTv
        ? 28.0
        : MediaQuery.sizeOf(context).width < 560
            ? 20.0
            : 36.0;

    return TvKitRow(
      tabId: tabId,
      rowId: _widgetId,
      sortOrder: sortOrder,
      itemCount: _items.length,
      onFocusUp: focusUp ?? () {},
      child: Padding(
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
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++) ...[
                if (i > 0) SizedBox(width: tabGap),
                ForjaUnderlineTab(
                  label: _items[i].label,
                  isActive: selected == _items[i].id,
                  onTap: () => scope.onSelect(
                    _widgetId,
                    _items[i].id,
                    toggle: _toggle,
                  ),
                  tvFocus: useTv,
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
          ),
        ),
      ),
    );
  }
}
