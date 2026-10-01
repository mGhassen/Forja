import 'package:flutter/material.dart';
import 'package:forja_foundation/components/focusable_tap.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

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
  final ValueNotifier<bool> _hoveredN = ValueNotifier(false);
  bool _removeFocused = false;

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
    _hoveredN.dispose();
    super.dispose();
  }

  void _setHovered(bool h) {
    if (_hoveredN.value == h) return;
    _hoveredN.value = h;
  }

  void _onRemoveFocusChange() {
    final focused = _removeFocus.hasFocus;
    if (_removeFocused == focused) return;
    setState(() => _removeFocused = focused);
    widget.onFocusChange?.call(focused);
  }

  /// Desktop: hover and focus are exclusive — hover wins under the pointer.
  bool _focusLit(BuildContext context, bool hovered) {
    if (widget.scaleOnHover && hovered) return false;
    return widget.selected ||
        ShellPaintScope.focusStyledOf(context, focused: _removeFocused);
  }

  Widget _titleFace({
    required bool highlighted,
    required Color color,
    required double iconSize,
    required double fontSize,
  }) {
    return Align(
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
  }

  Widget _removeFace({
    required bool highlighted,
    required bool removeLit,
  }) {
    return SizedBox(
      width: 36,
      height: 32,
      child: Center(
        child: Icon(
          Icons.close_rounded,
          size: highlighted ? 18 : 16,
          color: removeLit
              ? ForjaShellColors.textPrimary
              : ForjaShellColors.iconMuted,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleWrap = widget.titleInteractiveBuilder;
    final removeWrap = widget.removeInteractiveBuilder;

    // Faces rebuild on hover via ListenableBuilder; focus wraps stay stable.
    Widget titleFace;
    Widget removeFace;
    if (widget.scaleOnHover) {
      titleFace = ListenableBuilder(
        listenable: _hoveredN,
        builder: (context, _) {
          final focusLit = _focusLit(context, _hoveredN.value);
          final highlighted = focusLit;
          final color = highlighted
              ? ForjaShellColors.textPrimary
              : ForjaShellColors.textSecondary;
          return _titleFace(
            highlighted: highlighted,
            color: color,
            iconSize: highlighted ? 16.0 : 14.0,
            fontSize: highlighted
                ? widget.titleFontSizeSelected
                : widget.titleFontSize,
          );
        },
      );
      removeFace = ListenableBuilder(
        listenable: _hoveredN,
        builder: (context, _) {
          final focusLit = _focusLit(context, _hoveredN.value);
          return _removeFace(
            highlighted: focusLit,
            removeLit: focusLit &&
                ShellPaintScope.focusStyledOf(
                  context,
                  focused: _removeFocused,
                ),
          );
        },
      );
    } else {
      final focusLit = _focusLit(context, false);
      final highlighted = focusLit;
      final color = highlighted
          ? ForjaShellColors.textPrimary
          : ForjaShellColors.textSecondary;
      titleFace = _titleFace(
        highlighted: highlighted,
        color: color,
        iconSize: highlighted ? 16.0 : 14.0,
        fontSize: highlighted
            ? widget.titleFontSizeSelected
            : widget.titleFontSize,
      );
      removeFace = _removeFace(
        highlighted: highlighted,
        removeLit: focusLit &&
            ShellPaintScope.focusStyledOf(context, focused: _removeFocused),
      );
    }

    final titleChild = titleWrap != null
        ? titleWrap(
            child: titleFace,
            onTap: widget.onSelect,
            focusNode: widget.titleFocusNode,
            onFocusChange: widget.onFocusChange,
          )
        : FocusableTap(
            onTap: widget.onSelect,
            focusNode: widget.titleFocusNode,
            child: titleFace,
          );

    final removeChild = removeWrap != null
        ? removeWrap(
            child: removeFace,
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
            child: removeFace,
          );

    final innerRow = Row(
      children: [
        Expanded(child: titleChild),
        removeChild,
      ],
    );

    final Widget row;
    if (widget.scaleOnHover) {
      row = MouseRegion(
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        cursor: SystemMouseCursors.click,
        child: ListenableBuilder(
          listenable: _hoveredN,
          builder: (context, _) => Material(
            color: _hoveredN.value
                ? ForjaShellColors.inkHover
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            clipBehavior: Clip.antiAlias,
            child: innerRow,
          ),
        ),
      );
    } else {
      final highlighted = _focusLit(context, false);
      row = Material(
        color: highlighted ? ForjaShellColors.inkHover : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        clipBehavior: Clip.antiAlias,
        child: innerRow,
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: widget.verticalPadding),
      child: row,
    );
  }
}
