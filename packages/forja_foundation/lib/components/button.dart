import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:forja_foundation/tokens/forja_theme_extension.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

/// Visual tone for [Button].
enum ButtonVariant {
  primary,
  secondary,
  ghost,
  outline,
  destructive,
  /// Brand-green tinted fill at rest (Settings accent CTAs).
  accent,
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
class Button extends StatefulWidget {
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
    this.hoverColor,
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
  /// Rest foreground (outline border too). Pack kit: `color`.
  final Color? color;
  /// Hover / focus / press foreground. Pack kit: `hoverColor`.
  final Color? hoverColor;
  final double? iconSize;
  final bool compact;
  final double? height;
  final double? fontSize;
  final EdgeInsetsGeometry? padding;
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;

  @override
  State<Button> createState() => _ButtonState();
}

class _ButtonState extends State<Button> {
  final WidgetStatesController _states = WidgetStatesController();

  @override
  void initState() {
    super.initState();
    _states.addListener(_onStates);
  }

  @override
  void dispose() {
    _states.removeListener(_onStates);
    _states.dispose();
    super.dispose();
  }

  void _onStates() {
    if (!mounted) return;
    // Material ButtonStyleButton.initStatesController notifies sync during
    // child mount — setState there asserts "called during build".
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      setState(() {});
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final enabled = widget.onPressed != null && !widget.loading;
    final dims = _dims(
      widget.compact ? ButtonSize.sm : widget.size,
      height: widget.height,
      fontSize: widget.fontSize,
      padding: widget.padding,
    );
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final resolvedHeight = widget.height ??
        (tv ? dims.height * ShellTokens.tvChromeScale : dims.height);
    final resolvedFontSize = widget.fontSize ??
        (tv ? ShellTokens.tvTypeSize(dims.fontSize) : dims.fontSize);
    final resolvedPadding = widget.padding ??
        (tv
            ? EdgeInsets.symmetric(
                horizontal: switch (dims.padding) {
                  EdgeInsets e => e.horizontal / 2 * ShellTokens.tvChromeScale,
                  _ => 10.0,
                },
              )
            : dims.padding);
    // Explicit [iconSize] is caller-owned (already density-aware). Defaults densify.
    final resolvedIconSize = widget.iconSize ??
        ShellTokens.iconSizeFor(dims.iconSize, tv: tv);
    final colors = _resolveColors(
      theme,
      widget.variant,
      enabled,
      widget.color,
      widget.hoverColor,
      _states.value,
    );

    Widget content;
    if (widget.loading) {
      content = SizedBox(
        width: resolvedIconSize,
        height: resolvedIconSize,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: colors.foreground,
        ),
      );
    } else if (widget.child != null) {
      content = widget.child!;
    } else if (widget.size == ButtonSize.icon ||
        widget.variant == ButtonVariant.plainIcon) {
      content = Icon(
        widget.icon,
        size: resolvedIconSize,
        color: colors.foreground,
      );
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.icon != null) ...[
            Icon(
              widget.icon,
              size: resolvedIconSize,
              color: colors.foreground,
            ),
            SizedBox(width: theme.spaceSm),
          ],
          if (widget.label != null)
            Flexible(
              child: Text(
                widget.label!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.foreground,
                  fontSize: resolvedFontSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  decoration: widget.variant == ButtonVariant.link
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

    Widget button = _ButtonBase(
      onPressed: enabled ? widget.onPressed : null,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      enabled: enabled,
      statesController: _states,
      style: style,
      padding: resolvedPadding,
      constraints: BoxConstraints(
        minHeight: resolvedHeight,
        minWidth: widget.size == ButtonSize.icon ? resolvedHeight : 0,
      ),
      borderRadius: BorderRadius.circular(
        tv ? theme.radiusMd * ShellTokens.tvChromeScale : theme.radiusMd,
      ),
      tooltip: widget.tooltip,
      onKeyEvent: widget.onKeyEvent,
      child: content,
    );

    if (widget.expand) {
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
    Color? hoverColor,
    Set<WidgetState> states,
  ) {
    if (!enabled) {
      return _ButtonColors(
        foreground: (color ?? theme.textSecondary).withValues(alpha: 0.45),
        background: Colors.transparent,
        border: theme.borderSubtle,
      );
    }
    final engaged = _engaged(states);
    if (color != null) {
      // plainIcon: rest [color], hover/focus → brand green (or hoverColor).
      // No fill/border — keeps overlay glyphs (continue-watching X / i) clean.
      if (engaged && variant == ButtonVariant.plainIcon) {
        return _ButtonColors(
          foreground: hoverColor ?? theme.brandGreen,
          background: Colors.transparent,
          border: null,
        );
      }
      if (engaged && hoverColor != null) {
        return _ButtonColors(
          foreground: hoverColor,
          background: hoverColor.withValues(alpha: 0.12),
          border: hoverColor.withValues(alpha: 0.55),
        );
      }
      return _ButtonColors(
        foreground: color,
        background: Colors.transparent,
        border: variant == ButtonVariant.outline ? color : null,
      );
    }
    final engagedFg = hoverColor ?? theme.brandGreen;
    final engagedColors = _ButtonColors(
      foreground: engagedFg,
      background: engagedFg.withValues(alpha: 0.12),
      border: engagedFg.withValues(alpha: 0.55),
    );
    return switch (variant) {
      // White at rest; brand green (or pack hoverColor) on hover / focus / press.
      ButtonVariant.primary => engaged
          ? engagedColors
          : _ButtonColors(
              foreground: theme.textPrimary,
              background: Colors.white.withValues(alpha: 0.03),
              border: ForjaShellColors.ghostBorder,
            ),
      ButtonVariant.secondary => engaged
          ? engagedColors
          : _ButtonColors(
              foreground: theme.textPrimary,
              background: Colors.white.withValues(alpha: 0.03),
              border: ForjaShellColors.ghostBorder,
            ),
      ButtonVariant.ghost => engaged
          ? engagedColors
          : _ButtonColors(
              foreground: theme.textPrimary,
              background: Colors.transparent,
              border: null,
            ),
      ButtonVariant.outline => engaged
          ? engagedColors
          : _ButtonColors(
              foreground: theme.textPrimary,
              background: Colors.transparent,
              border: theme.borderSubtle,
            ),
      ButtonVariant.destructive => const _ButtonColors(
          foreground: Color(0xFFF87171),
          background: Color(0x1FF87171),
          border: Color(0x8CF87171),
        ),
      ButtonVariant.accent => engaged
          ? _ButtonColors(
              foreground: theme.brandGreen,
              background: theme.brandGreen.withValues(alpha: 0.18),
              border: theme.brandGreen.withValues(alpha: 0.7),
            )
          : _ButtonColors(
              foreground: theme.brandGreen,
              background: theme.brandGreen.withValues(alpha: 0.12),
              border: theme.brandGreen.withValues(alpha: 0.55),
            ),
      ButtonVariant.link => engaged
          ? engagedColors
          : _ButtonColors(
              foreground: theme.brandGreen,
              background: Colors.transparent,
              border: null,
            ),
      ButtonVariant.plainIcon => engaged
          ? _ButtonColors(
              foreground: engagedFg,
              background: Colors.transparent,
              border: null,
            )
          : _ButtonColors(
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
    this.statesController,
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
  final WidgetStatesController? statesController;
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
      statesController: statesController,
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
