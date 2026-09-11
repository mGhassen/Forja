import 'package:flutter/material.dart';
import 'package:forja/shared/shell/shell_focusable_tap.dart';
import 'package:forja/shared/shell/forja_shell_scope.dart';
import 'package:forja/shared/shell/tv/shell_tv_coordinator.dart';
import 'package:forja_foundation/components/mood_circle.dart';

export 'package:forja_foundation/components/mood_circle.dart'
    show MoodCircle, MoodCircleLayout;

/// Host resolve helpers for [MoodCircleLayout] (reads [ShellScope]).
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
    if (ShellScope.inputPolicyOf(context).useFocusableMoodChips) {
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
    this.tvTabId,
    this.tvRowId,
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
  final String? tvTabId;
  final String? tvRowId;
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
    final policy = ShellScope.inputPolicyOf(context);
    return widget.selected ||
        _hovered ||
        policy.focusStyled(context, focused: _focused);
  }

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final paint = MoodCircle(
      label: widget.label,
      icon: widget.icon,
      accent: widget.accent,
      layout: widget.layout,
      selected: widget.selected,
      active: _active(context),
      scaleOnActive: policy.scaleOnHover,
      size: widget.layout.circleSize,
    );

    if (policy.useFocusableMoodChips) {
      return shellFocusableTap(
        context: context,
        onTap: widget.onTap,
        borderRadius: widget.layout.circleSize / 2,
        scaleOnFocus: 1.0,
        onFocusChange: (focused) => setState(() => _focused = focused),
        onHoverChange: policy.scaleOnHover
            ? (hovered) => setState(() => _hovered = hovered)
            : null,
        listIndex: widget.listIndex,
        tvTabId: widget.tvTabId,
        tvRowId: widget.tvRowId,
        tvItemIndex: widget.listIndex,
        tvZone: ShellTvZone.chipStrip,
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
