import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';

/// Circle + label layout for home-style mood / sport pickers.
class ShellMoodCircleLayout {
  const ShellMoodCircleLayout({
    required this.circleSize,
    required this.itemWidth,
    required this.horizontalGap,
    required this.rowHeight,
    required this.labelFontSize,
    required this.iconSize,
    required this.iconSizeActive,
    required this.labelMaxLines,
  });

  final double circleSize;
  final double itemWidth;
  final double horizontalGap;
  final double rowHeight;
  final double labelFontSize;
  final double iconSize;
  final double iconSizeActive;
  final int labelMaxLines;

  static const desktop = ShellMoodCircleLayout(
    circleSize: 72,
    itemWidth: 96,
    horizontalGap: 24,
    // Circle + gap + 2-line label + bottom breathing room (avoids descender clip).
    rowHeight: 72 + 8 + 34 + 8,
    labelFontSize: 12.5,
    iconSize: 26,
    iconSizeActive: 34,
    labelMaxLines: 2,
  );

  double contentWidth(int itemCount) {
    if (itemCount <= 0) return 0;
    return itemCount * itemWidth + (itemCount - 1) * horizontalGap;
  }

  /// TV: shrink items so every chip fits on screen without horizontal scroll.
  static ShellMoodCircleLayout forTv({
    required int itemCount,
    required double maxWidth,
  }) {
    if (itemCount <= 0) return desktop;

    const edgePad = 12.0;
    final available = (maxWidth - edgePad * 2).clamp(240.0, double.infinity);

    var gap = 10.0;
    var itemWidth = 78.0;
    while (itemCount * itemWidth + (itemCount - 1) * gap > available &&
        itemWidth > 52) {
      itemWidth -= 2;
      gap = math.max(4, gap - 1);
    }

    final circleSize = (itemWidth * 0.74).clamp(40.0, 54.0);
    final labelFontSize = itemWidth < 64 ? 9.5 : 10.5;
    const labelLineHeight = 1.15;
    final rowHeight = circleSize + 6 + labelFontSize * labelLineHeight + 8;
    final iconSize = circleSize * 0.42;
    final iconSizeActive = circleSize * 0.52;

    return ShellMoodCircleLayout(
      circleSize: circleSize,
      itemWidth: itemWidth,
      horizontalGap: gap,
      rowHeight: rowHeight,
      labelFontSize: labelFontSize,
      iconSize: iconSize,
      iconSizeActive: iconSizeActive,
      labelMaxLines: 1,
    );
  }

  static ShellMoodCircleLayout resolve(
    BuildContext context, {
    required int itemCount,
    required double maxWidth,
  }) {
    if (ShellScope.inputPolicyOf(context).useFocusableMoodChips) {
      return forTv(itemCount: itemCount, maxWidth: maxWidth);
    }
    return desktop;
  }
}

/// Circular icon picker - same visual language as Home mood row.
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

  final ShellMoodCircleLayout layout;
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

  Widget _circle() {
    final layout = widget.layout;
    final accent = widget.accent;
    final active = _active(context);
    final bgAlpha = widget.selected ? 0.62 : (active ? 0.42 : 0.22);
    final borderColor = widget.selected
        ? accent
        : active
        ? accent.withValues(alpha: 0.95)
        : accent.withValues(alpha: 0.35);
    final policy = ShellScope.inputPolicyOf(context);
    final scaleOnActive = policy.scaleOnHover;
    final iconSize = active ? layout.iconSizeActive : layout.iconSize;
    final icon = Icon(widget.icon, size: iconSize, color: Colors.white);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: layout.circleSize,
      height: layout.circleSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: bgAlpha),
        border: Border.all(
          color: borderColor,
          width: widget.selected ? 2.5 : 1.5,
        ),
        boxShadow: active && scaleOnActive
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.4),
                  blurRadius: layout.circleSize * 0.2,
                ),
              ]
            : null,
      ),
      child: scaleOnActive
          ? AnimatedScale(
              scale: active ? 1.12 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: icon,
            )
          : icon,
    );
  }

  Widget _content() {
    final layout = widget.layout;
    final active = _active(context);
    return SizedBox(
      width: layout.itemWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _circle(),
          SizedBox(height: layout.labelMaxLines == 1 ? 6 : 8),
          Text(
            widget.label,
            maxLines: layout.labelMaxLines,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.72),
              fontSize: layout.labelFontSize,
              fontWeight: widget.selected ||
                      ShellScope.inputPolicyOf(context)
                          .focusStyled(context, focused: _focused)
                  ? FontWeight.w700
                  : FontWeight.w600,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _content();
    final policy = ShellScope.inputPolicyOf(context);
    final borderRadius = widget.layout.circleSize / 2;

    if (policy.useFocusableMoodChips) {
      return shellFocusableTap(
        context: context,
        onTap: widget.onTap,
        borderRadius: borderRadius,
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
        child: content,
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: content,
      ),
    );
  }
}
