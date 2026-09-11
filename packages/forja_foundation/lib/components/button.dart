import 'package:flutter/material.dart';
import 'package:forja_foundation/primitives/button.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Visual tone for [Button].
enum ButtonVariant {
  primary,
  secondary,
  ghost,
  outline,
  destructive,
  link,
  plainIcon,
}

/// Size scale for [Button].
enum ButtonSize {
  sm,
  md,
  lg,
  icon,
}

/// Forja action button — one family; close/back/icon are usages via variant/size.
class Button extends StatelessWidget {
  const Button({
    super.key,
    this.onPressed,
    this.child,
    this.label,
    this.icon,
    this.variant = ButtonVariant.secondary,
    this.size = ButtonSize.md,
    this.loading = false,
    this.expand = false,
    this.focusNode,
    this.autofocus = false,
    this.tooltip,
  }) : assert(child != null || label != null || icon != null);

  final VoidCallback? onPressed;
  final Widget? child;
  final String? label;
  final IconData? icon;
  final ButtonVariant variant;
  final ButtonSize size;
  final bool loading;
  final bool expand;
  final FocusNode? focusNode;
  final bool autofocus;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final enabled = onPressed != null && !loading;
    final dims = _dims(size);
    final colors = _resolveColors(theme, variant, enabled);

    Widget content;
    if (loading) {
      content = SizedBox(
        width: dims.iconSize,
        height: dims.iconSize,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: colors.foreground,
        ),
      );
    } else if (child != null) {
      content = child!;
    } else if (size == ButtonSize.icon || variant == ButtonVariant.plainIcon) {
      content = Icon(icon, size: dims.iconSize, color: colors.foreground);
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dims.iconSize, color: colors.foreground),
            SizedBox(width: theme.spaceSm),
          ],
          if (label != null)
            Flexible(
              child: Text(
                label!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.foreground,
                  fontSize: dims.fontSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  decoration: variant == ButtonVariant.link
                      ? TextDecoration.underline
                      : TextDecoration.none,
                ),
              ),
            ),
        ],
      );
    }

    final style = ButtonStyle(
      foregroundColor: WidgetStatePropertyAll(colors.foreground),
      backgroundColor: WidgetStatePropertyAll(colors.background),
      overlayColor: WidgetStatePropertyAll(
        colors.foreground.withValues(alpha: 0.08),
      ),
      side: colors.border != null
          ? WidgetStatePropertyAll(
              BorderSide(color: colors.border!, width: 1.5),
            )
          : const WidgetStatePropertyAll(BorderSide.none),
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
    );

    Widget button = PrimitiveButton(
      onPressed: enabled ? onPressed : null,
      focusNode: focusNode,
      autofocus: autofocus,
      enabled: enabled,
      style: style,
      padding: dims.padding,
      constraints: BoxConstraints(
        minHeight: dims.height,
        minWidth: size == ButtonSize.icon ? dims.height : 0,
      ),
      borderRadius: BorderRadius.circular(theme.radiusMd),
      tooltip: tooltip,
      child: content,
    );

    if (expand) {
      button = SizedBox(width: double.infinity, child: button);
    }
    return button;
  }

  static _ButtonDims _dims(ButtonSize size) => switch (size) {
        ButtonSize.sm => const _ButtonDims(
            height: 32,
            fontSize: 12,
            iconSize: 16,
            padding: EdgeInsets.symmetric(horizontal: 12),
          ),
        ButtonSize.md => const _ButtonDims(
            height: 40,
            fontSize: 14,
            iconSize: 18,
            padding: EdgeInsets.symmetric(horizontal: 18),
          ),
        ButtonSize.lg => const _ButtonDims(
            height: 48,
            fontSize: 16,
            iconSize: 20,
            padding: EdgeInsets.symmetric(horizontal: 22),
          ),
        ButtonSize.icon => const _ButtonDims(
            height: 40,
            fontSize: 14,
            iconSize: 20,
            padding: EdgeInsets.zero,
          ),
      };

  static _ButtonColors _resolveColors(
    ForjaThemeExtension theme,
    ButtonVariant variant,
    bool enabled,
  ) {
    if (!enabled) {
      return _ButtonColors(
        foreground: theme.textSecondary.withValues(alpha: 0.45),
        background: Colors.transparent,
        border: theme.borderSubtle,
      );
    }
    return switch (variant) {
      ButtonVariant.primary => _ButtonColors(
          foreground: theme.brandGreen,
          background: theme.brandGreen.withValues(alpha: 0.12),
          border: theme.brandGreen.withValues(alpha: 0.55),
        ),
      ButtonVariant.secondary => _ButtonColors(
          foreground: theme.textPrimary,
          background: Colors.white.withValues(alpha: 0.03),
          border: ForjaShellColors.ghostBorder,
        ),
      ButtonVariant.ghost => _ButtonColors(
          foreground: theme.textPrimary,
          background: Colors.transparent,
          border: null,
        ),
      ButtonVariant.outline => _ButtonColors(
          foreground: theme.textPrimary,
          background: Colors.transparent,
          border: theme.borderSubtle,
        ),
      ButtonVariant.destructive => const _ButtonColors(
          foreground: Color(0xFFF87171),
          background: Color(0x1FF87171),
          border: Color(0x8CF87171),
        ),
      ButtonVariant.link => _ButtonColors(
          foreground: theme.brandGreen,
          background: Colors.transparent,
          border: null,
        ),
      ButtonVariant.plainIcon => _ButtonColors(
          foreground: theme.textSecondary,
          background: Colors.transparent,
          border: null,
        ),
    };
  }
}

class _ButtonDims {
  const _ButtonDims({
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

class _ButtonColors {
  const _ButtonColors({
    required this.foreground,
    required this.background,
    required this.border,
  });

  final Color foreground;
  final Color background;
  final Color? border;
}
