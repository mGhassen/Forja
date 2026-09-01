import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';

/// Shared status strip for My List (Plan / Watching / …).
class CatalogStatusTabs extends StatelessWidget {
  const CatalogStatusTabs({
    super.key,
    required this.tabId,
    required this.selected,
    required this.onSelect,
    this.tabs,
    this.rowId,
    this.sortOrder = 1,
    this.onUp,
    this.onDown,
  });

  final String tabId;
  final String selected;
  final ValueChanged<String> onSelect;
  final List<({String id, String title})>? tabs;
  final String? rowId;
  final int sortOrder;
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  static const defaultTabs = [
    (id: 'plantowatch', title: 'Plan to Watch'),
    (id: 'watching', title: 'Watching'),
    (id: 'hold', title: 'On Hold'),
    (id: 'completed', title: 'Completed'),
    (id: 'dropped', title: 'Dropped'),
  ];

  @override
  Widget build(BuildContext context) {
    final useTv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final statusTabs = tabs ?? defaultTabs;
    final tvRowId = rowId ?? kCatalogMyListStatusRowId;
    return TvCatalogRow(
      tabId: tabId,
      rowId: tvRowId,
      sortOrder: sortOrder,
      itemCount: statusTabs.length,
      onFocusUp: onUp,
      onFocusDown: onDown,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          ShellTokens.compactChromeLeadingInset(context),
          0,
          ShellTokens.bodyHorizontalPadding,
          0,
        ),
        child: SizedBox(
          height: 42,
          child: FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: Row(
              children: [
                for (var i = 0; i < statusTabs.length; i++)
                  Expanded(
                    child: _tab(context, i, useTv, statusTabs, tvRowId),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(
    BuildContext context,
    int i,
    bool useTv,
    List<({String id, String title})> statusTabs,
    String tvRowId,
  ) {
    final tab = statusTabs[i];
    final on = tab.id == selected;
    if (!useTv) {
      final label = Text(
        tab.title,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: on
              ? ForjaShellColors.textPrimary
              : ForjaShellColors.textSecondary,
          fontWeight: on ? FontWeight.w600 : FontWeight.w500,
          fontSize: 13,
        ),
      );
      return InkWell(
        onTap: () => onSelect(tab.id),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(child: Center(child: label)),
            Container(
              height: 2,
              color: on ? ForjaShellColors.brandGreen : Colors.transparent,
            ),
          ],
        ),
      );
    }
    return _StatusTabFocus(
      label: tab.title,
      selected: on,
      listIndex: i,
      tabId: tabId,
      rowId: tvRowId,
      onTap: () => onSelect(tab.id),
      onUp: onUp,
      onDown: onDown,
    );
  }
}

class _StatusTabFocus extends StatefulWidget {
  const _StatusTabFocus({
    required this.label,
    required this.selected,
    required this.listIndex,
    required this.tabId,
    required this.rowId,
    required this.onTap,
    this.onUp,
    this.onDown,
  });

  final String label;
  final bool selected;
  final int listIndex;
  final String tabId;
  final String rowId;
  final VoidCallback onTap;
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  @override
  State<_StatusTabFocus> createState() => _StatusTabFocusState();
}

class _StatusTabFocusState extends State<_StatusTabFocus> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final emphasize =
        widget.selected || policy.focusStyled(context, focused: _focused);
    final label = Text(
      widget.label,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: emphasize
            ? ForjaShellColors.textPrimary
            : ForjaShellColors.textSecondary,
        fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
        fontSize: 13,
      ),
    );
    return shellFocusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: 0,
      listIndex: widget.listIndex,
      tvTabId: widget.tabId,
      tvRowId: widget.rowId,
      tvZone: ShellTvZone.chipStrip,
      tvItemIndex: widget.listIndex,
      onUpEdge: widget.onUp,
      onDownEdge: widget.onDown,
      onFocusChange: (f) => setState(() => _focused = f),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(child: Center(child: label)),
          Container(
            height: 2,
            color: widget.selected
                ? ForjaShellColors.brandGreen
                : Colors.transparent,
          ),
        ],
      ),
    );
  }
}

const kCatalogMyListStatusRowId = 'tabs';
const kCatalogMyListKindRowId = 'kind';
