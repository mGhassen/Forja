import 'package:flutter/material.dart' hide Badge;
import 'package:forja_foundation/theme/forja_theme_extension.dart';

/// Visual tone for [Badge].
enum BadgeVariant {
  default_,
  secondary,
  destructive,
  outline,
}

/// Size scale for [Badge].
enum BadgeSize {
  sm,
  md,
}

/// Compact status / count badge.
class Badge extends StatelessWidget {
  const Badge({
    super.key,
    this.label,
    this.child,
    this.variant = BadgeVariant.default_,
    this.size = BadgeSize.md,
  }) : assert(label != null || child != null);

  final String? label;
  final Widget? child;
  final BadgeVariant variant;
  final BadgeSize size;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final dims = _dims(size);
    final colors = _resolve(theme, variant);

    return Container(
      constraints: BoxConstraints(minHeight: dims.height),
      padding: dims.padding,
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
        border: colors.border != null
            ? Border.all(color: colors.border!)
            : null,
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          color: colors.foreground,
          fontSize: dims.fontSize,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
        child: child ?? Text(label!),
      ),
    );
  }

  static _BadgeDims _dims(BadgeSize size) => switch (size) {
        BadgeSize.sm => const _BadgeDims(
            height: 18,
            fontSize: 10,
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          ),
        BadgeSize.md => const _BadgeDims(
            height: 22,
            fontSize: 11,
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          ),
      };

  static _BadgeColors _resolve(
    ForjaThemeExtension theme,
    BadgeVariant variant,
  ) {
    return switch (variant) {
      BadgeVariant.default_ => _BadgeColors(
          foreground: theme.bgDark,
          background: theme.brandGreen,
          border: null,
        ),
      BadgeVariant.secondary => _BadgeColors(
          foreground: theme.textSecondary,
          background: Colors.white.withValues(alpha: 0.08),
          border: null,
        ),
      BadgeVariant.destructive => const _BadgeColors(
          foreground: Color(0xFFF87171),
          background: Color(0x1FF87171),
          border: null,
        ),
      BadgeVariant.outline => _BadgeColors(
          foreground: theme.textSecondary,
          background: Colors.transparent,
          border: theme.borderSubtle,
        ),
    };
  }
}

class _BadgeDims {
  const _BadgeDims({
    required this.height,
    required this.fontSize,
    required this.padding,
  });

  final double height;
  final double fontSize;
  final EdgeInsetsGeometry padding;
}

class _BadgeColors {
  const _BadgeColors({
    required this.foreground,
    required this.background,
    required this.border,
  });

  final Color foreground;
  final Color background;
  final Color? border;
}
