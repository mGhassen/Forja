import 'package:flutter/material.dart';

import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';

/// Recent search row: select title to run the query; X deletes it.
///
/// Desktop hover matches recommendation rows (one full-row ink fill).
/// On TV, Right from the title focuses the X; Left from X returns to the title;
/// Right from X runs [onRightPastRemove] (usually film cards).
class RecentSearchHelperTile extends StatefulWidget {
  const RecentSearchHelperTile({
    super.key,
    required this.title,
    required this.selected,
    required this.listIndex,
    required this.tvTabId,
    required this.tvRowId,
    required this.onSelect,
    required this.onRemove,
    this.titleFocusNode,
    this.onUpEdge,
    this.onDownEdge,
    this.onRightPastRemove,
    this.onFocusChange,
    this.titleFontSize = 16,
    this.titleFontSizeSelected = 18,
    this.verticalPadding = 4,
  });

  final String title;
  final bool selected;
  final int listIndex;
  final String tvTabId;
  final String tvRowId;
  final VoidCallback onSelect;
  final VoidCallback onRemove;
  final FocusNode? titleFocusNode;
  final VoidCallback? onUpEdge;
  final VoidCallback? onDownEdge;
  final VoidCallback? onRightPastRemove;
  final ValueChanged<bool>? onFocusChange;
  final double titleFontSize;
  final double titleFontSizeSelected;
  final double verticalPadding;

  @override
  State<RecentSearchHelperTile> createState() => _RecentSearchHelperTileState();
}

class _RecentSearchHelperTileState extends State<RecentSearchHelperTile> {
  late final FocusNode _removeFocus;
  bool _removeFocused = false;
  bool _hovered = false;

  String get _removeRowId => '${widget.tvRowId}-remove';

  @override
  void initState() {
    super.initState();
    _removeFocus = FocusNode(
      debugLabel: 'recent-search-remove-${widget.tvTabId}-${widget.listIndex}',
    );
    _removeFocus.addListener(_onRemoveFocusChange);
  }

  @override
  void dispose() {
    _removeFocus.removeListener(_onRemoveFocusChange);
    _removeFocus.dispose();
    super.dispose();
  }

  void _onRemoveFocusChange() {
    final focused = _removeFocus.hasFocus;
    if (_removeFocused == focused) return;
    setState(() => _removeFocused = focused);
    widget.onFocusChange?.call(focused);
  }

  void _focusTitle() {
    final node = widget.titleFocusNode;
    if (node != null && node.canRequestFocus) {
      node.requestFocus();
      return;
    }
    ShellTvFocusCoordinator.focusRowItem(
      widget.tvTabId,
      widget.tvRowId,
      widget.listIndex,
    );
  }

  void _focusRemove() {
    if (_removeFocus.canRequestFocus) {
      _removeFocus.requestFocus();
      return;
    }
    ShellTvFocusCoordinator.focusRowItem(
      widget.tvTabId,
      _removeRowId,
      widget.listIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final policy =
        ShellScope.maybeOf(context)?.inputPolicy ?? ShellInputPolicy.desktop;
    final useTvFocus = policy.useFocusableMoodChips;
    final highlighted = widget.selected || _removeFocused;
    // Desktop: same soft fill as recommendation InkWell hover (one row, not split).
    final showHoverFill = !useTvFocus && _hovered;
    final color = highlighted
        ? ForjaShellColors.textPrimary
        : ForjaShellColors.textSecondary;
    final iconSize = highlighted ? 16.0 : 14.0;
    final fontSize =
        highlighted ? widget.titleFontSizeSelected : widget.titleFontSize;

    Widget row = Row(
      children: [
        Expanded(
          child: shellFocusableTap(
            context: context,
            onTap: widget.onSelect,
            borderRadius: 4,
            scaleOnFocus: 1.0,
            navLeftAlways: true,
            listIndex: widget.listIndex,
            tvTabId: widget.tvTabId,
            tvRowId: widget.tvRowId,
            tvZone: ShellTvZone.chipStrip,
            tvItemIndex: widget.listIndex,
            focusNode: widget.titleFocusNode,
            onUpEdge: widget.onUpEdge,
            onDownEdge: widget.onDownEdge,
            onRightEdge: _focusRemove,
            ensureVisibleMode: ShellTvEnsureVisibleMode.row,
            onFocusChange: widget.onFocusChange,
            suppressInkHover: true,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Icon(
                    Icons.history,
                    size: iconSize,
                    color: color.withValues(
                      alpha: highlighted ? 0.9 : 0.55,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: fontSize,
                        fontWeight:
                            highlighted ? FontWeight.w600 : FontWeight.w400,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        shellFocusableTap(
          context: context,
          onTap: widget.onRemove,
          borderRadius: 4,
          scaleOnFocus: 1.0,
          tvTabId: widget.tvTabId,
          tvRowId: _removeRowId,
          tvZone: ShellTvZone.chipStrip,
          tvItemIndex: widget.listIndex,
          focusNode: _removeFocus,
          onUpEdge: widget.onUpEdge,
          onDownEdge: widget.onDownEdge,
          onLeftEdge: _focusTitle,
          onRightEdge: widget.onRightPastRemove,
          ensureVisibleMode: ShellTvEnsureVisibleMode.row,
          suppressInkHover: true,
          child: SizedBox(
            width: 36,
            height: 32,
            child: Center(
              child: Icon(
                Icons.close_rounded,
                size: highlighted ? 18 : 16,
                color: _removeFocused
                    ? ForjaShellColors.textPrimary
                    : ForjaShellColors.iconMuted,
              ),
            ),
          ),
        ),
      ],
    );

    row = Material(
      color: showHoverFill ? ForjaShellColors.inkHover : Colors.transparent,
      borderRadius: BorderRadius.circular(4),
      clipBehavior: Clip.antiAlias,
      child: row,
    );

    if (!useTvFocus) {
      row = MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: row,
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: widget.verticalPadding),
      child: row,
    );
  }
}
