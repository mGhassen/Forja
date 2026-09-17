import 'package:flutter/material.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/components/mood_circle.dart';
import 'package:forja_foundation/tokens/forja_motion_theme.dart';

export 'package:forja_foundation/components/mood_circle.dart'
    show MoodCircle, MoodCircleLayout;

/// Resolve helpers for [MoodCircleLayout] (reads [ShellPaintScope]).
abstract final class ShellMoodCircleLayout {
  static MoodCircleLayout get desktop => MoodCircleLayout.desktop;
  static MoodCircleLayout get tvScrollable => MoodCircleLayout.tvScrollable;

  static MoodCircleLayout forTv({
    required int itemCount,
    required double maxWidth,
  }) =>
      MoodCircleLayout.forTv(itemCount: itemCount, maxWidth: maxWidth);

  static MoodCircleLayout resolve(
    BuildContext context, {
    required int itemCount,
    required double maxWidth,
  }) {
    if (ShellPaintScope.useTvFocusOf(context)) {
      return MoodCircleLayout.forTv(itemCount: itemCount, maxWidth: maxWidth);
    }
    return MoodCircleLayout.desktop;
  }
}

/// Host TV/focus wrapper around accent [MoodCircle].
class ShellMoodCircleItem extends StatefulWidget {
  const ShellMoodCircleItem({
    super.key,
    required this.layout,
    required this.label,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
    this.listIndex,
    this.onDownEdge,
    this.onUpEdge,
    this.onLeftEdge,
    this.onRightEdge,
  });

  final MoodCircleLayout layout;
  final String label;
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback? onTap;
  final int? listIndex;
  final VoidCallback? onDownEdge;
  final VoidCallback? onUpEdge;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;

  @override
  State<ShellMoodCircleItem> createState() => _ShellMoodCircleItemState();
}

class _ShellMoodCircleItemState extends State<ShellMoodCircleItem> {
  bool _hovered = false;
  bool _focused = false;

  bool _active(BuildContext context) {
    return widget.selected ||
        _hovered ||
        ShellPaintScope.focusStyledOf(context, focused: _focused);
  }

  @override
  Widget build(BuildContext context) {
    final useTv = ShellPaintScope.useTvFocusOf(context);
    final scaleOnHover = ShellPaintScope.scaleOnHoverOf(context);
    final paint = MoodCircle(
      label: widget.label,
      icon: widget.icon,
      accent: widget.accent,
      layout: widget.layout,
      selected: widget.selected,
      active: _active(context),
      scaleOnActive: scaleOnHover,
      size: widget.layout.circleSize,
    );

    if (useTv) {
      return ShellPaintScope.focusableTap(
        context: context,
        onTap: widget.onTap,
        borderRadius: widget.layout.circleSize / 2,
        motion: ForjaMotionPreset.fillOnly,
        onFocusChange: (focused) => setState(() => _focused = focused),
        onHoverChange: scaleOnHover
            ? (hovered) => setState(() => _hovered = hovered)
            : null,
        listIndex: widget.listIndex,
        tvItemIndex: widget.listIndex,
        tvZone: ShellPaintTvZone.chipStrip,
        onDownEdge: widget.onDownEdge,
        onUpEdge: widget.onUpEdge,
        onLeftEdge: widget.onLeftEdge,
        onRightEdge: widget.onRightEdge,
        child: paint,
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: paint,
      ),
    );
  }
}
