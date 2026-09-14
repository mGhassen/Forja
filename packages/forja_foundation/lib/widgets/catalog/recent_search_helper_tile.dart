import 'package:flutter/material.dart';
import 'package:forja_foundation/components/focusable_tap.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Recent search row paint — select title to run query; X deletes (Zone A).
///
/// Host injects TV focus via [titleInteractiveBuilder] / [removeInteractiveBuilder].
class RecentSearchHelperTile extends StatefulWidget {
  const RecentSearchHelperTile({
    super.key,
    required this.title,
    required this.selected,
    required this.onSelect,
    required this.onRemove,
    this.titleFocusNode,
    this.scaleOnHover = true,
    this.titleFontSize = 16,
    this.titleFontSizeSelected = 18,
    this.verticalPadding = 4,
    this.titleInteractiveBuilder,
    this.removeInteractiveBuilder,
    this.onFocusChange,
  });

  final String title;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onRemove;
  final FocusNode? titleFocusNode;
  final bool scaleOnHover;
  final double titleFontSize;
  final double titleFontSizeSelected;
  final double verticalPadding;
  final ValueChanged<bool>? onFocusChange;

  final Widget Function({
    required Widget child,
    required VoidCallback onTap,
    ValueChanged<bool>? onFocusChange,
    FocusNode? focusNode,
  })? titleInteractiveBuilder;

  final Widget Function({
    required Widget child,
    required VoidCallback onTap,
    ValueChanged<bool>? onFocusChange,
    FocusNode? focusNode,
  })? removeInteractiveBuilder;

  @override
  State<RecentSearchHelperTile> createState() => _RecentSearchHelperTileState();
}

class _RecentSearchHelperTileState extends State<RecentSearchHelperTile> {
  late final FocusNode _removeFocus;
  bool _removeFocused = false;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _removeFocus = FocusNode(debugLabel: 'recent-search-remove');
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

  @override
  Widget build(BuildContext context) {
    final highlighted = widget.selected || _removeFocused;
    final showHoverFill = widget.scaleOnHover && _hovered;
    final color = highlighted
        ? ForjaShellColors.textPrimary
        : ForjaShellColors.textSecondary;
    final iconSize = highlighted ? 16.0 : 14.0;
    final fontSize =
        highlighted ? widget.titleFontSizeSelected : widget.titleFontSize;

    Widget titleChild = Align(
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Icon(
            Icons.history,
            size: iconSize,
            color: color.withValues(alpha: highlighted ? 0.9 : 0.55),
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
                fontWeight: highlighted ? FontWeight.w600 : FontWeight.w400,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );

    Widget removeChild = SizedBox(
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
    );

    final titleWrap = widget.titleInteractiveBuilder;
    final removeWrap = widget.removeInteractiveBuilder;

    titleChild = titleWrap != null
        ? titleWrap(
            child: titleChild,
            onTap: widget.onSelect,
            focusNode: widget.titleFocusNode,
            onFocusChange: widget.onFocusChange,
          )
        : FocusableTap(
            onTap: widget.onSelect,
            focusNode: widget.titleFocusNode,
            child: titleChild,
          );

    removeChild = removeWrap != null
        ? removeWrap(
            child: removeChild,
            onTap: widget.onRemove,
            focusNode: _removeFocus,
            onFocusChange: (f) {
              setState(() => _removeFocused = f);
              widget.onFocusChange?.call(f);
            },
          )
        : FocusableTap(
            onTap: widget.onRemove,
            focusNode: _removeFocus,
            child: removeChild,
          );

    Widget row = Row(
      children: [
        Expanded(child: titleChild),
        removeChild,
      ],
    );

    row = Material(
      color: showHoverFill ? ForjaShellColors.inkHover : Colors.transparent,
      borderRadius: BorderRadius.circular(4),
      clipBehavior: Clip.antiAlias,
      child: row,
    );

    if (widget.scaleOnHover) {
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
