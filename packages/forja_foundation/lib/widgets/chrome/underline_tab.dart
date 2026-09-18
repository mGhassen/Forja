import 'package:flutter/material.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:google_fonts/google_fonts.dart';

/// Kit primitive — underline text tab (My List–style kind menus).
class ForjaUnderlineTab extends StatefulWidget {
  const ForjaUnderlineTab({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.tvFocus,
    required this.tabId,
    required this.rowId,
    required this.listIndex,
    required this.onDownEdge,
    this.onLeftEdge,
    this.onRightEdge,
    this.focusNode,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool tvFocus;
  final String tabId;
  final String rowId;
  final int listIndex;
  final VoidCallback onDownEdge;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final FocusNode? focusNode;

  @override
  State<ForjaUnderlineTab> createState() => _ForjaUnderlineTabState();
}

class _ForjaUnderlineTabState extends State<ForjaUnderlineTab> {
  static const _animDuration = Duration(milliseconds: 280);
  static const _hoverT = 0.62;
  static const _selectedT = 1.0;

  final ValueNotifier<bool> _hoveredN = ValueNotifier(false);
  bool _focused = false;
  /// After toggle-deselect, pointer/focus is still on the tab — hover paint
  /// looks like selection. Hold idle until the pointer/focus actually leaves.
  bool _suppressHighlightUntilLeave = false;

  @override
  void dispose() {
    _hoveredN.dispose();
    super.dispose();
  }

  void _setHovered(bool hovered) {
    if (_hoveredN.value == hovered) return;
    _hoveredN.value = hovered;
    if (!hovered && _suppressHighlightUntilLeave) {
      setState(() => _suppressHighlightUntilLeave = false);
    }
  }

  @override
  void didUpdateWidget(covariant ForjaUnderlineTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive && !widget.isActive) {
      _suppressHighlightUntilLeave = true;
    } else if (!oldWidget.isActive && widget.isActive) {
      _suppressHighlightUntilLeave = false;
    }
  }

  double get _visualTarget {
    if (widget.isActive) return _selectedT;
    if (_suppressHighlightUntilLeave) return 0;
    if (_hoveredN.value ||
        ShellPaintScope.focusStyledOf(context, focused: _focused)) {
      return _hoverT;
    }
    return 0;
  }

  void _onFocusChange(bool focused) {
    setState(() {
      _focused = focused;
      if (!focused) _suppressHighlightUntilLeave = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final child = TweenAnimationBuilder<double>(
      tween: Tween<double>(end: _visualTarget),
      duration: _animDuration,
      curve: Curves.easeInOutCubic,
      builder: (context, t, _) {
        final idle = ForjaShellColors.cinematic.textSecondary;
        final hoverWhite = Colors.white.withValues(alpha: 0.92);
        final color = t <= 0
            ? idle
            : t < _hoverT
                ? Color.lerp(idle, hoverWhite, t / _hoverT)!
                : Color.lerp(
                    hoverWhite,
                    Colors.white,
                    (t - _hoverT) / (_selectedT - _hoverT),
                  )!;
        final tabHeight = 34.0;
        final tabFont = 17.0;
        final hoverW = 28.0;
        final underline = t <= 0
            ? 0.0
            : t < _hoverT
                ? hoverW * (t / _hoverT)
                : hoverW +
                    4.0 * ((t - _hoverT) / (_selectedT - _hoverT));
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: tabHeight,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: tabFont,
                    fontWeight: FontWeight.lerp(
                      FontWeight.w500,
                      FontWeight.w700,
                      t,
                    ),
                    color: color,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ),
            SizedBox(height: ShellTokens.shellCategoryUnderlineGap),
            Container(
              height: ShellTokens.shellNavUnderlineHeight,
              width: underline,
              decoration: BoxDecoration(
                color: underline > 0 ? color : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        );
      },
    );

    if (widget.tvFocus) {
      return ShellPaintScope.focusableTap(
        context: context,
        onTap: widget.onTap,
        borderRadius: 4,
        scaleOnFocus: 1.0,
        listIndex: widget.listIndex,
        tvTabId: widget.tabId,
        tvRowId: widget.rowId,
        tvZone: ShellPaintTvZone.row,
        tvItemIndex: widget.listIndex,
        onDownEdge: widget.onDownEdge,
        onLeftEdge: widget.onLeftEdge,
        onRightEdge: widget.onRightEdge,
        focusNode: widget.focusNode,
        onFocusChange: _onFocusChange,
        onHoverChange: _setHovered,
        child: ListenableBuilder(
          listenable: _hoveredN,
          builder: (context, _) => child,
        ),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: ListenableBuilder(
          listenable: _hoveredN,
          builder: (context, _) => child,
        ),
      ),
    );
  }
}
