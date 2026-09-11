import 'package:flutter/material.dart' hide Chip;
import 'package:forja_foundation/theme/forja_theme_extension.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Visual tone for [Chip].
enum ChipVariant {
  idle,
  selected,
}

/// Size scale for [Chip].
enum ChipSize {
  sm,
  md,
}

/// Selectable / filter chip — idle vs selected.
class Chip extends StatelessWidget {
  const Chip({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = ChipVariant.idle,
    this.size = ChipSize.md,
    this.leading,
    this.focusNode,
  });

  final String label;
  final VoidCallback? onPressed;
  final ChipVariant variant;
  final ChipSize size;
  final Widget? leading;
  final FocusNode? focusNode;

  bool get _selected => variant == ChipVariant.selected;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final dims = _dims(size);
    final bg = _selected
        ? ForjaShellColors.chipSelectedBg
        : Colors.white.withValues(alpha: 0.03);
    final border = _selected
        ? ForjaShellColors.chipSelectedBorder
        : theme.borderSubtle;
    final fg = _selected ? theme.textPrimary : theme.textSecondary;

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
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                IconTheme(
                  data: IconThemeData(color: fg, size: dims.iconSize),
                  child: leading!,
                ),
                SizedBox(width: theme.spaceSm),
              ],
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: dims.fontSize,
                  fontWeight: _selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static _ChipDims _dims(ChipSize size) => switch (size) {
        ChipSize.sm => const _ChipDims(
            height: 28,
            fontSize: 12,
            iconSize: 14,
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          ),
        ChipSize.md => const _ChipDims(
            height: 36,
            fontSize: 13,
            iconSize: 16,
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          ),
      };
}

class _ChipDims {
  const _ChipDims({
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
