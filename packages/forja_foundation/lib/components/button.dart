import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_theme_extension.dart';
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
    this.color,
    this.iconSize,
    this.compact = false,
    this.height,
    this.fontSize,
    this.padding,
    this.onKeyEvent,
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
  final Color? color;
  final double? iconSize;
  final bool compact;
  final double? height;
  final double? fontSize;
  final EdgeInsetsGeometry? padding;
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final enabled = onPressed != null && !loading;
    final dims = _dims(
      compact ? ButtonSize.sm : size,
      height: height,
      fontSize: fontSize,
      padding: padding,
    );
    // Idle palette for the spinner; label/icon inherit ButtonStyle fg so
    // primary can go gray→green on hover/focus without a StatefulWidget.
    final idle = _resolveColors(
      theme,
      variant,
      enabled,
      color,
      const <WidgetState>{},
    );

    Widget content;
    if (loading) {
      content = SizedBox(
        width: dims.iconSize,
        height: dims.iconSize,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: idle.foreground,
        ),
      );
    } else if (child != null) {
      content = child!;
    } else if (size == ButtonSize.icon || variant == ButtonVariant.plainIcon) {
      content = Icon(icon, size: iconSize ?? dims.iconSize);
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize ?? dims.iconSize),
            SizedBox(width: theme.spaceSm),
          ],
          if (label != null)
            Flexible(
              child: Text(
                label!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
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
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        return _resolveColors(theme, variant, enabled, color, states)
            .foreground;
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        return _resolveColors(theme, variant, enabled, color, states)
            .background;
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        final fg = _resolveColors(theme, variant, enabled, color, states)
            .foreground;
        return fg.withValues(alpha: 0.08);
      }),
      side: WidgetStateProperty.resolveWith((states) {
        final border =
            _resolveColors(theme, variant, enabled, color, states).border;
        if (border == null) return BorderSide.none;
        return BorderSide(color: border, width: 1.5);
      }),
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
    );

    Widget button = _ButtonBase(
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
      onKeyEvent: onKeyEvent,
      child: content,
    );

    if (expand) {
      button = SizedBox(width: double.infinity, child: button);
    }
    return button;
  }

  static _ButtonDims _dims(
    ButtonSize size, {
    double? height,
    double? fontSize,
    EdgeInsetsGeometry? padding,
  }) {
    final base = switch (size) {
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
    if (height == null && fontSize == null && padding == null) return base;
    return _ButtonDims(
      height: height ?? base.height,
      fontSize: fontSize ?? base.fontSize,
      iconSize: base.iconSize,
      padding: padding ?? base.padding,
    );
  }

  static bool _engaged(Set<WidgetState> states) =>
      states.contains(WidgetState.hovered) ||
      states.contains(WidgetState.focused) ||
      states.contains(WidgetState.pressed);

  static _ButtonColors _resolveColors(
    ForjaThemeExtension theme,
    ButtonVariant variant,
    bool enabled,
    Color? color,
    Set<WidgetState> states,
  ) {
    if (!enabled) {
      return _ButtonColors(
        foreground: (color ?? theme.textSecondary).withValues(alpha: 0.45),
        background: Colors.transparent,
        border: theme.borderSubtle,
      );
    }
    if (color != null) {
      return _ButtonColors(
        foreground: color,
        background: Colors.transparent,
        border: variant == ButtonVariant.outline ? color : null,
      );
    }
    return switch (variant) {
      // Gray at rest; brand green on hover / focus / press.
      ButtonVariant.primary => _engaged(states)
          ? _ButtonColors(
              foreground: theme.brandGreen,
              background: theme.brandGreen.withValues(alpha: 0.12),
              border: theme.brandGreen.withValues(alpha: 0.55),
            )
          : _ButtonColors(
              foreground: theme.textSecondary,
              background: Colors.white.withValues(alpha: 0.03),
              border: ForjaShellColors.ghostBorder,
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

/// Hit target / focus / semantics shell — style values in; no variants.
class _ButtonBase extends StatelessWidget {
  const _ButtonBase({
    required this.onPressed,
    required this.child,
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
    this.style,
    this.padding,
    this.constraints,
    this.borderRadius,
    this.tooltip,
    this.onKeyEvent,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool enabled;
  final ButtonStyle? style;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;
  final BorderRadius? borderRadius;
  final String? tooltip;
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;

  @override
  Widget build(BuildContext context) {
    final effectiveEnabled = enabled && onPressed != null;
    Widget button = TextButton(
      onPressed: effectiveEnabled ? onPressed : null,
      focusNode: focusNode,
      autofocus: autofocus,
      style: (style ?? const ButtonStyle()).copyWith(
        padding: padding != null
            ? WidgetStatePropertyAll(padding)
            : null,
        minimumSize: constraints != null
            ? WidgetStatePropertyAll(
                Size(constraints!.minWidth, constraints!.minHeight),
              )
            : null,
        shape: borderRadius != null
            ? WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: borderRadius!),
              )
            : null,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      child: child,
    );
    if (tooltip != null && tooltip!.isNotEmpty) {
      button = Tooltip(message: tooltip!, child: button);
    }
    final node = focusNode;
    final keyHook = onKeyEvent;
    if (node != null && keyHook != null) {
      button = _FocusKeyHook(node: node, onKeyEvent: keyHook, child: button);
    }
    return button;
  }
}

class _FocusKeyHook extends StatefulWidget {
  const _FocusKeyHook({
    required this.node,
    required this.onKeyEvent,
    required this.child,
  });

  final FocusNode node;
  final KeyEventResult Function(FocusNode node, KeyEvent event) onKeyEvent;
  final Widget child;

  @override
  State<_FocusKeyHook> createState() => _FocusKeyHookState();
}

class _FocusKeyHookState extends State<_FocusKeyHook> {
  @override
  void initState() {
    super.initState();
    widget.node.onKeyEvent = widget.onKeyEvent;
  }

  @override
  void didUpdateWidget(covariant _FocusKeyHook oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node != widget.node) {
      if (oldWidget.node.onKeyEvent == oldWidget.onKeyEvent) {
        oldWidget.node.onKeyEvent = null;
      }
    }
    widget.node.onKeyEvent = widget.onKeyEvent;
  }

  @override
  void dispose() {
    if (widget.node.onKeyEvent == widget.onKeyEvent) {
      widget.node.onKeyEvent = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
