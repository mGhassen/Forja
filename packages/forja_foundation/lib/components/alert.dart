import 'package:flutter/material.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';

/// Visual tone for [Alert].
enum AlertVariant {
  info,
  success,
  warning,
  destructive,
}

/// Banner / callout alert.
class Alert extends StatelessWidget {
  const Alert({
    super.key,
    this.title,
    this.description,
    this.child,
    this.variant = AlertVariant.info,
    this.icon,
    this.onDismiss,
  }) : assert(title != null || description != null || child != null);

  final String? title;
  final String? description;
  final Widget? child;
  final AlertVariant variant;
  final IconData? icon;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final colors = _colors(theme, variant);
    final resolvedIcon = icon ??
        switch (variant) {
          AlertVariant.info => Icons.info_outline,
          AlertVariant.success => Icons.check_circle_outline,
          AlertVariant.warning => Icons.warning_amber_outlined,
          AlertVariant.destructive => Icons.error_outline,
        };

    return Container(
      padding: EdgeInsets.all(theme.spaceMd),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(theme.radiusMd),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(resolvedIcon, size: 20, color: colors.foreground),
          SizedBox(width: theme.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: TextStyle(
                      color: colors.foreground,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (description != null) ...[
                  if (title != null) SizedBox(height: theme.spaceSm / 2),
                  Text(
                    description!,
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
                if (child != null) ...[
                  if (title != null || description != null)
                    SizedBox(height: theme.spaceSm),
                  child!,
                ],
              ],
            ),
          ),
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              icon: Icon(Icons.close, size: 18, color: theme.textSecondary),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
        ],
      ),
    );
  }

  static _AlertColors _colors(
    ForjaThemeExtension theme,
    AlertVariant variant,
  ) {
    return switch (variant) {
      AlertVariant.info => _AlertColors(
          foreground: theme.brandGreen,
          background: theme.brandGreen.withValues(alpha: 0.08),
          border: theme.brandGreen.withValues(alpha: 0.35),
        ),
      AlertVariant.success => _AlertColors(
          foreground: theme.brandGreen,
          background: theme.brandGreen.withValues(alpha: 0.1),
          border: theme.brandGreen.withValues(alpha: 0.45),
        ),
      AlertVariant.warning => const _AlertColors(
          foreground: Color(0xFFFBBF24),
          background: Color(0x1AFBBF24),
          border: Color(0x66FBBF24),
        ),
      AlertVariant.destructive => const _AlertColors(
          foreground: Color(0xFFF87171),
          background: Color(0x1FF87171),
          border: Color(0x66F87171),
        ),
    };
  }
}

/// Compact inline alert (same API, denser padding).
class InlineAlert extends StatelessWidget {
  const InlineAlert({
    super.key,
    this.title,
    this.description,
    this.variant = AlertVariant.info,
    this.icon,
  });

  final String? title;
  final String? description;
  final AlertVariant variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Alert(
      title: title,
      description: description,
      variant: variant,
      icon: icon,
    );
  }
}

class _AlertColors {
  const _AlertColors({
    required this.foreground,
    required this.background,
    required this.border,
  });

  final Color foreground;
  final Color background;
  final Color border;
}
