import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Layout metrics for circular mood / category pickers.
class MoodCircleLayout {
  const MoodCircleLayout({
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

  static const desktop = MoodCircleLayout(
    circleSize: 72,
    itemWidth: 96,
    horizontalGap: 24,
    rowHeight: 72 + 8 + 34 + 8,
    labelFontSize: 12.5,
    iconSize: 26,
    iconSizeActive: 34,
    labelMaxLines: 2,
  );

  static const tvScrollable = MoodCircleLayout(
    circleSize: 54,
    itemWidth: 78,
    horizontalGap: 10,
    rowHeight: 54 + 6 + 12 + 8,
    labelFontSize: 10.5,
    iconSize: 22.7,
    iconSizeActive: 28.1,
    labelMaxLines: 1,
  );

  double contentWidth(int itemCount) {
    if (itemCount <= 0) return 0;
    return itemCount * itemWidth + (itemCount - 1) * horizontalGap;
  }

  /// Shrink items so every chip fits without horizontal scroll.
  static MoodCircleLayout forTv({
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

    return MoodCircleLayout(
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
}

/// Generic circular mood / category selector.
class MoodCircle extends StatelessWidget {
  const MoodCircle({
    super.key,
    required this.label,
    this.imageUrl,
    this.selected = false,
    this.onTap,
    this.child,
    this.size = 72,
    this.focusNode,
    this.accent,
    this.icon,
    this.layout,
    this.active = false,
    this.scaleOnActive = true,
  });

  final String label;
  final String? imageUrl;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? child;
  final double size;
  final FocusNode? focusNode;

  /// When set with [icon], paints the accent circle language (sport/mood chips).
  final Color? accent;
  final IconData? icon;
  final MoodCircleLayout? layout;
  final bool active;
  final bool scaleOnActive;

  @override
  Widget build(BuildContext context) {
    if (layout != null && icon != null && accent != null) {
      return _AccentMoodCircle(
        layout: layout!,
        label: label,
        icon: icon!,
        accent: accent!,
        selected: selected,
        active: active || selected,
        scaleOnActive: scaleOnActive,
        onTap: onTap,
        focusNode: focusNode,
      );
    }

    final theme = ForjaThemeExtension.of(context);
    final border = selected ? theme.brandGreen : theme.borderSubtle;
    final bg =
        selected ? ForjaShellColors.chipSelectedBg : theme.surfaceElevated;
    final url = imageUrl?.trim() ?? '';

    Widget content;
    if (child != null) {
      content = child!;
    } else if (url.isNotEmpty &&
        (url.startsWith('http://') || url.startsWith('https://'))) {
      content = Image.network(
        url,
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (_, _, _) => Icon(
          Icons.mood,
          color: theme.textSecondary,
          size: size * 0.4,
        ),
      );
    } else if (url.isNotEmpty) {
      content = Icon(Icons.mood, color: theme.textSecondary, size: size * 0.4);
    } else {
      content = Text(
        label.isNotEmpty ? label[0].toUpperCase() : '?',
        style: TextStyle(
          color: theme.textPrimary,
          fontSize: size * 0.32,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            focusNode: focusNode,
            customBorder: const CircleBorder(),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bg,
                border: Border.all(color: border, width: selected ? 2.5 : 1),
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: content,
            ),
          ),
        ),
        SizedBox(height: theme.spaceSm),
        SizedBox(
          width: size + 8,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? theme.textPrimary : theme.textSecondary,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _AccentMoodCircle extends StatelessWidget {
  const _AccentMoodCircle({
    required this.layout,
    required this.label,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.active,
    required this.scaleOnActive,
    this.onTap,
    this.focusNode,
  });

  final MoodCircleLayout layout;
  final String label;
  final IconData icon;
  final Color accent;
  final bool selected;
  final bool active;
  final bool scaleOnActive;
  final VoidCallback? onTap;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final bgAlpha = selected ? 0.62 : (active ? 0.42 : 0.22);
    final borderColor = selected
        ? accent
        : active
            ? accent.withValues(alpha: 0.95)
            : accent.withValues(alpha: 0.35);
    final iconSize = active ? layout.iconSizeActive : layout.iconSize;
    final iconWidget = Icon(icon, size: iconSize, color: Colors.white);

    final circle = AnimatedContainer(
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
          width: selected ? 2.5 : 1.5,
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
              child: iconWidget,
            )
          : iconWidget,
    );

    final body = SizedBox(
      width: layout.itemWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          circle,
          SizedBox(height: layout.labelMaxLines == 1 ? 6 : 8),
          Text(
            label,
            maxLines: layout.labelMaxLines,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.white : Colors.white.withValues(alpha: 0.72),
              fontSize: layout.labelFontSize,
              fontWeight: selected || active ? FontWeight.w700 : FontWeight.w600,
              height: 1.15,
            ),
          ),
        ],
      ),
    );

    if (onTap == null && focusNode == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        focusNode: focusNode,
        customBorder: const CircleBorder(),
        child: body,
      ),
    );
  }
}
