import 'package:flutter/material.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/tokens/mobile_chrome_tokens.dart';

/// Shared status strip for bookmark / list hubs (Plan / Watching / …).
class ForjaStatusTabs extends StatelessWidget {
  const ForjaStatusTabs({
    super.key,
    required this.tabId,
    required this.selected,
    required this.onSelect,
    this.tabs,
    this.counts,
    this.rowId,
    this.sortOrder = 1,
    this.onUp,
    this.onDown,
    this.onLeft,
    this.onRight,
    this.inShellTopBar = false,
    this.scrollable = false,
  });

  final String tabId;
  final String selected;
  final ValueChanged<String> onSelect;
  final List<({String id, String title})>? tabs;

  /// Optional search hit counts keyed by tab id — shown when > 0.
  final Map<String, int>? counts;
  final String? rowId;
  final int sortOrder;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final VoidCallback? onLeft;
  final VoidCallback? onRight;
  final bool inShellTopBar;

  /// Phone: tabs keep their natural width and the strip scrolls sideways,
  /// so long labels ("Plan to Watch") never truncate. Default: equal widths.
  final bool scrollable;

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
            child: _strip(
              children: [
                for (var i = 0; i < statusTabs.length; i++)
                  _cell(
                    _StatusTab(
                      label: _statusTabLabel(
                        statusTabs[i].title,
                        counts?[statusTabs[i].id],
                      ),
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

  Widget _cell(Widget tab) {
    if (!scrollable) return Expanded(child: tab);
    // IntrinsicWidth bounds the tab to its label so the stretched underline
    // matches the label instead of an infinite scroll-row width.
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: MobileChromeTokens.statusTabScrollPadH,
      ),
      child: IntrinsicWidth(child: tab),
    );
  }

  Widget _strip({required List<Widget> children}) {
    if (!scrollable) return Row(children: children);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

String _statusTabLabel(String title, int? count) {
  if (count == null || count <= 0) return title;
  return '$title · $count';
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
    final focusHover =
        hovered || ShellPaintScope.focusStyledOf(context, focused: _focused);
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
