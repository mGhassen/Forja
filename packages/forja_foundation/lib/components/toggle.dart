import 'package:flutter/material.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Visual tone for [Toggle].
enum ToggleVariant {
  outline,
  ghost,
}

/// Size scale for [Toggle].
enum ToggleSize {
  sm,
  md,
}

/// Pressable on/off segment (toolbar / filter).
class Toggle extends StatelessWidget {
  const Toggle({
    super.key,
    required this.pressed,
    required this.onPressed,
    this.label,
    this.icon,
    this.child,
    this.variant = ToggleVariant.outline,
    this.size = ToggleSize.md,
    this.focusNode,
  }) : assert(child != null || label != null || icon != null);

  final bool pressed;
  final VoidCallback? onPressed;
  final String? label;
  final IconData? icon;
  final Widget? child;
  final ToggleVariant variant;
  final ToggleSize size;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final dims = _dims(size);
    final selected = pressed;
    final bg = selected
        ? ForjaShellColors.chipSelectedBg
        : (variant == ToggleVariant.ghost
            ? Colors.transparent
            : Colors.white.withValues(alpha: 0.03));
    final border = selected
        ? ForjaShellColors.chipSelectedBorder
        : (variant == ToggleVariant.ghost ? null : theme.borderSubtle);
    final fg = selected ? theme.textPrimary : theme.textSecondary;

    Widget content = child ??
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: dims.iconSize, color: fg),
              if (label != null) SizedBox(width: theme.spaceSm),
            ],
            if (label != null)
              Text(
                label!,
                style: TextStyle(
                  color: fg,
                  fontSize: dims.fontSize,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
          ],
        );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        focusNode: focusNode,
        borderRadius: BorderRadius.circular(theme.radiusMd),
        child: Container(
          constraints: BoxConstraints(minHeight: dims.height),
          padding: dims.padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(theme.radiusMd),
            border: border != null ? Border.all(color: border) : null,
          ),
          child: content,
        ),
      ),
    );
  }

  static _ToggleDims _dims(ToggleSize size) => switch (size) {
        ToggleSize.sm => const _ToggleDims(
            height: 28,
            fontSize: 12,
            iconSize: 14,
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          ),
        ToggleSize.md => const _ToggleDims(
            height: 36,
            fontSize: 13,
            iconSize: 16,
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          ),
      };
}

/// Selection mode for [ToggleGroup].
enum ToggleGroupType {
  single,
  multiple,
}

/// Groups [Toggle] children with shared selection.
class ToggleGroup extends StatelessWidget {
  const ToggleGroup({
    super.key,
    required this.children,
    this.type = ToggleGroupType.single,
    this.orientation = Axis.horizontal,
    this.spacing,
  });

  final List<Widget> children;
  final ToggleGroupType type;
  final Axis orientation;
  final double? spacing;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final gap = spacing ?? theme.spaceSm;
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        spaced.add(
          orientation == Axis.horizontal
              ? SizedBox(width: gap)
              : SizedBox(height: gap),
        );
      }
      spaced.add(children[i]);
    }
    return Flex(
      direction: orientation,
      mainAxisSize: MainAxisSize.min,
      children: spaced,
    );
  }
}

class _ToggleDims {
  const _ToggleDims({
    required this.height,
    required this.fontSize,
    required this.iconSize,
    required this.padding,
  });

  final double height;
  final double fontSize;
  final double iconSize;
  final EdgeInsetsGeometry padding;
}
