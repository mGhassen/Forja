import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_motion_theme.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/tokens/forja_theme_extension.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/utils/cover_urls.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

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
    required this.labelGap,
    this.labelLineHeight = 1.15,
  });

  final double circleSize;
  final double itemWidth;
  final double horizontalGap;
  final double rowHeight;
  final double labelFontSize;
  final double iconSize;
  final double iconSizeActive;
  final int labelMaxLines;
  final double labelGap;
  final double labelLineHeight;

  static const desktop = MoodCircleLayout(
    circleSize: 72,
    itemWidth: 96,
    horizontalGap: 24,
    // circle + gap + label slot + bottom pad (slot > 2× line for wrapping slack).
    rowHeight: 72 + 8 + 34 + 8,
    labelFontSize: 12.5,
    iconSize: 26,
    iconSizeActive: 34,
    labelMaxLines: 2,
    labelGap: 8,
    labelLineHeight: 1.15,
  );

  /// Hand-tuned leanback packing ([ShellTokens.moodCircle*] — not chrome-scaled).
  static const tvScrollable = MoodCircleLayout(
    circleSize: ShellTokens.moodCircleSizeTv,
    itemWidth: ShellTokens.moodCircleItemWidthTv,
    horizontalGap: ShellTokens.moodCircleGapTv,
    rowHeight: ShellTokens.moodCircleRowHeightTv,
    labelFontSize: ShellTokens.moodCircleLabelFontSizeTv,
    iconSize: ShellTokens.moodCircleIconSizeTv,
    iconSizeActive: ShellTokens.moodCircleIconSizeActiveTv,
    labelMaxLines: ShellTokens.moodCircleLabelMaxLinesTv,
    labelGap: ShellTokens.moodCircleLabelGapTv,
    labelLineHeight: ShellTokens.moodCircleLabelLineHeightTv,
  );

  double contentWidth(int itemCount) {
    if (itemCount <= 0) return 0;
    return itemCount * itemWidth + (itemCount - 1) * horizontalGap;
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
        // Hover/focus only — selected paints via [selected] (label color vs bold).
        active: active,
        scaleOnActive: scaleOnActive,
        onTap: onTap,
        focusNode: focusNode,
      );
    }

    final theme = ForjaThemeExtension.of(context);
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final labelFontSize = layout?.labelFontSize ??
        (tv ? ShellTokens.tvMetaFontSize : 12.0);
    final border = selected ? theme.brandGreen : theme.borderSubtle;
    final bg =
        selected ? ForjaShellColors.chipSelectedBg : theme.surfaceElevated;
    final url = paintableNetworkImageUrl(imageUrl?.trim() ?? '');

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
              fontSize: labelFontSize,
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
    final lit = selected || active;
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final bgAlpha = selected ? 0.62 : (active ? 0.42 : 0.22);
    final borderColor = selected
        ? accent
        : active
            ? accent.withValues(alpha: 0.95)
            : accent.withValues(alpha: 0.35);
    final borderWidth = selected
        ? (tv
            ? ShellTokens.moodCircleBorderWidthSelectedTv
            : ShellTokens.moodCircleBorderWidthSelected)
        : (tv
            ? ShellTokens.moodCircleBorderWidthTv
            : ShellTokens.moodCircleBorderWidth);
    final iconSize = lit ? layout.iconSizeActive : layout.iconSize;
    final iconWidget = Icon(icon, size: iconSize, color: Colors.white);
    final chip = ForjaMotionTheme.of(context).chipLift;

    final circle = AnimatedContainer(
      duration: chip.duration,
      curve: chip.resolvedCurve,
      width: layout.circleSize,
      height: layout.circleSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: bgAlpha),
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
        boxShadow: lit && scaleOnActive
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.4),
                  blurRadius: layout.circleSize * 0.2,
                ),
              ]
            : null,
      ),
      child: scaleOnActive
          ? ForjaMotionScale(
              preset: ForjaMotionPreset.chipLift,
              active: lit,
              child: iconWidget,
            )
          : iconWidget,
    );

    // Fixed height + top-aligned circle so 1/2/3-line labels don't shift
    // neighbors vertically in a Row (default CrossAxisAlignment.center).
    final body = SizedBox(
      width: layout.itemWidth,
      height: layout.rowHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          circle,
          SizedBox(height: layout.labelGap),
          Text(
            label,
            maxLines: layout.labelMaxLines,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected
                  ? accent
                  : Colors.white.withValues(alpha: active ? 1.0 : 0.72),
              fontSize: layout.labelFontSize,
              fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              height: layout.labelLineHeight,
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
