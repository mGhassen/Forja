import 'package:flutter/material.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Shared status strip for bookmark / list hubs (Plan / Watching / …).
class ForjaStatusTabs extends StatelessWidget {
  const ForjaStatusTabs({
    super.key,
    required this.tabId,
    required this.selected,
    required this.onSelect,
    this.tabs,
    this.rowId,
    this.sortOrder = 1,
    this.onUp,
    this.onDown,
    this.onLeft,
    this.onRight,
    this.inShellTopBar = false,
  });

  final String tabId;
  final String selected;
  final ValueChanged<String> onSelect;
  final List<({String id, String title})>? tabs;
  final String? rowId;
  final int sortOrder;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final VoidCallback? onLeft;
  final VoidCallback? onRight;
  final bool inShellTopBar;

  static const defaultTabs = [
    (id: 'plantowatch', title: 'Plan to Watch'),
    (id: 'watching', title: 'Watching'),
    (id: 'hold', title: 'On Hold'),
    (id: 'completed', title: 'Completed'),
    (id: 'dropped', title: 'Dropped'),
  ];

  @override
  Widget build(BuildContext context) {
    final useTv = ShellPaintScope.useTvFocusOf(context);
    final tvDensity = ShellPaintScope.usesTvDensityOf(context);
    final statusTabs = tabs ?? defaultTabs;
    final tvRowId = rowId ?? kKitStatusTabsRowId;
    return ShellPaintScope.tvRow(
      context: context,
      tabId: tabId,
      rowId: tvRowId,
      sortOrder: sortOrder,
      itemCount: statusTabs.length,
      onFocusUp: onUp,
      onFocusDown: onDown,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          inShellTopBar
              ? ShellTokens.shellTopBarMenuLeadingInset(context)
              : ShellTokens.compactChromeLeadingInset(context),
          inShellTopBar
              ? (tvDensity
                  ? ShellTokens.kitTopBarStatusRowTopGapTv
                  : ShellTokens.kitTopBarStatusRowTopGap)
              : 0,
          ShellTokens.bodyHorizontalPadding,
          0,
        ),
        child: SizedBox(
          height: tvDensity
              ? ShellTokens.kitTopBarStatusRowHeightTv
              : ShellTokens.kitTopBarStatusRowHeight,
          child: FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: Row(
              children: [
                for (var i = 0; i < statusTabs.length; i++)
                  Expanded(
                    child: _StatusTab(
                      label: statusTabs[i].title,
                      fontSize: tvDensity ? ShellTokens.tvBodyFontSize : 13.0,
                      selected: statusTabs[i].id == selected,
                      listIndex: i,
                      tabId: tabId,
                      rowId: tvRowId,
                      useTv: useTv,
                      onTap: () => onSelect(statusTabs[i].id),
                      onUp: onUp,
                      onDown: onDown,
                      onLeft: i == 0 ? onLeft : null,
                      onRight: i == statusTabs.length - 1 ? onRight : null,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusTab extends StatefulWidget {
  const _StatusTab({
    required this.label,
    required this.fontSize,
    required this.selected,
    required this.listIndex,
    required this.tabId,
    required this.rowId,
    required this.useTv,
    required this.onTap,
    this.onUp,
    this.onDown,
    this.onLeft,
    this.onRight,
  });

  final String label;
  final double fontSize;
  final bool selected;
  final int listIndex;
  final String tabId;
  final String rowId;
  final bool useTv;
  final VoidCallback onTap;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final VoidCallback? onLeft;
  final VoidCallback? onRight;

  @override
  State<_StatusTab> createState() => _StatusTabState();
}

class _StatusTabState extends State<_StatusTab> {
  final ValueNotifier<bool> _hoveredN = ValueNotifier(false);
  bool _focused = false;

  @override
  void dispose() {
    _hoveredN.dispose();
    super.dispose();
  }

  void _setHovered(bool hovered) {
    if (_hoveredN.value == hovered) return;
    _hoveredN.value = hovered;
  }

  Widget _label(bool hovered) {
    // Hover / focus → brand green (including over the selected tab).
    // Selected idle → white; underline stays green when selected.
    final focusHover = hovered ||
        ShellPaintScope.focusStyledOf(context, focused: _focused);
    final Color color;
    final FontWeight weight;
    if (focusHover) {
      color = ForjaShellColors.brandGreen;
      weight = FontWeight.w700;
    } else if (widget.selected) {
      color = ForjaShellColors.textPrimary;
      weight = FontWeight.w700;
    } else {
      color = ForjaShellColors.textSecondary;
      weight = FontWeight.w500;
    }
    return Text(
      widget.label,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontWeight: weight,
        fontSize: widget.fontSize,
      ),
    );
  }

  Widget _column(bool hovered) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(child: Center(child: _label(hovered))),
        Container(
          height: 2,
          color: widget.selected
              ? ForjaShellColors.brandGreen
              : Colors.transparent,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = ListenableBuilder(
      listenable: _hoveredN,
      builder: (context, _) => _column(_hoveredN.value),
    );

    if (widget.useTv) {
      return ShellPaintScope.focusableTap(
        context: context,
        onTap: widget.onTap,
        borderRadius: 0,
        scaleOnFocus: 1.0,
        listIndex: widget.listIndex,
        tvTabId: widget.tabId,
        tvRowId: widget.rowId,
        tvZone: ShellPaintTvZone.chipStrip,
        tvItemIndex: widget.listIndex,
        onUpEdge: widget.onUp,
        onDownEdge: widget.onDown,
        onLeftEdge: widget.onLeft,
        onRightEdge: widget.onRight,
        onFocusChange: (f) => setState(() => _focused = f),
        onHoverChange: _setHovered,
        suppressInkHover: true,
        showFocusFill: false,
        child: body,
      );
    }

    // No Material InkWell — theme primary must not tint selected labels.
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: body,
      ),
    );
  }
}

const kKitStatusTabsRowId = 'tabs';
