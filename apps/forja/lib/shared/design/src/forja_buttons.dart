import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/design/src/forja_shell_colors.dart';
import 'package:forja/shared/design/src/shell_input_policy.dart';
import 'package:forja/shared/design/src/shell_scope.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:google_fonts/google_fonts.dart';

typedef ForjaInteractiveBuilder = Widget Function(bool hover, bool pressed);

class ForjaInteractive extends StatefulWidget {
  const ForjaInteractive({
    super.key,
    required this.builder,
    this.onTap,
    this.hoverScale = 1.06,
    this.pressScale = 0.94,
    this.scaleAlignment = Alignment.center,
    this.autoFocus = false,
    this.focusNode,
    this.onKeyEvent,
    this.tvMeta,
  });

  final ForjaInteractiveBuilder builder;
  final VoidCallback? onTap;
  final double hoverScale;
  final double pressScale;
  final Alignment scaleAlignment;
  final bool autoFocus;
  final FocusNode? focusNode;
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;
  final ShellTvFocusMeta? tvMeta;

  @override
  State<ForjaInteractive> createState() => _ForjaInteractiveState();
}

class _ForjaInteractiveState extends State<ForjaInteractive> {
  bool _hover = false;
  bool _pressed = false;
  bool _focused = false;
  FocusNode? _ownedNode;

  FocusNode get _effectiveNode => widget.focusNode ?? _ownedNode!;

  ShellInputPolicy _policy(BuildContext context) =>
      ShellScope.maybeOf(context)?.inputPolicy ?? ShellInputPolicy.desktop;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _ownedNode = FocusNode(debugLabel: 'forja-interactive');
    }
  }

  @override
  void didUpdateWidget(covariant ForjaInteractive oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      if (widget.focusNode == null) {
        _ownedNode ??= FocusNode(debugLabel: 'forja-interactive');
      } else {
        _ownedNode?.dispose();
        _ownedNode = null;
      }
    }
  }

  @override
  void dispose() {
    _ownedNode?.dispose();
    super.dispose();
  }

  double _scaleFor(ShellInputPolicy policy) {
    if (_pressed) return widget.pressScale;
    if (policy.scaleOnHover && _hover) return widget.hoverScale;
    if (policy.scaleOnFocus && _focused) return widget.hoverScale;
    return 1.0;
  }

  bool _activeFor(ShellInputPolicy policy) =>
      (policy.scaleOnHover && _hover) || (policy.scaleOnFocus && _focused);

  @override
  Widget build(BuildContext context) {
    final policy = _policy(context);
    final body = AnimatedScale(
      scale: _scaleFor(policy),
      alignment: widget.scaleAlignment,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      child: widget.builder(_activeFor(policy), _pressed),
    );

    Widget interactive = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _pressed = false;
      }),
      cursor: SystemMouseCursors.click,
      child: widget.onTap != null
          ? GestureDetector(
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              onTap: widget.onTap,
              behavior: HitTestBehavior.opaque,
              child: body,
            )
          : Listener(
              onPointerDown: (_) => setState(() => _pressed = true),
              onPointerUp: (_) => setState(() => _pressed = false),
              onPointerCancel: (_) => setState(() => _pressed = false),
              behavior: HitTestBehavior.translucent,
              child: body,
            ),
    );

    if (widget.onTap == null) return interactive;

    return Focus(
      focusNode: _effectiveNode,
      debugLabel: _effectiveNode.debugLabel ?? 'forja-interactive',
      autofocus: widget.autoFocus,
      onFocusChange: (focused) {
        setState(() => _focused = focused);
        if (focused) {
          widget.tvMeta?.notifyFocused(_effectiveNode);
        }
      },
      onKeyEvent: (node, event) {
        final custom = widget.onKeyEvent?.call(node, event);
        if (custom == KeyEventResult.handled) return KeyEventResult.handled;
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (shellTvIsActivateKey(event)) {
          widget.onTap!();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: interactive,
    );
  }
}

/// Text-only CTA — no border, no filled background.
class ForjaGhostButton extends StatelessWidget {
  const ForjaGhostButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.autoFocus = false,
    this.focusNode,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool autoFocus;
  final FocusNode? focusNode;

  Color get _color => ForjaShellColors.textPrimary;

  @override
  Widget build(BuildContext context) {
    return ForjaInteractive(
      onTap: onTap,
      autoFocus: autoFocus,
      focusNode: focusNode,
      hoverScale: 1.04,
      pressScale: 0.96,
      builder: (hover, pressed) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 22, color: _color),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: GoogleFonts.inter(
                  color: _color,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Bare icon action — soft circular fill on hover/press/focus, no border.
class ForjaPlainIcon extends StatefulWidget {
  const ForjaPlainIcon({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.color,
    this.size = 24,
    this.hitSize,
    this.hoverScale = 1.08,
    this.pressScale = 0.94,
    this.child,
    this.focusNode,
    this.onKeyEvent,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final Color? color;
  final double size;
  final double? hitSize;
  final double hoverScale;
  final double pressScale;
  final Widget? child;
  final FocusNode? focusNode;
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;

  @override
  State<ForjaPlainIcon> createState() => _ForjaPlainIconState();
}

class _ForjaPlainIconState extends State<ForjaPlainIcon> {
  bool _hover = false;
  bool _pressed = false;
  bool _focused = false;

  double get _resolvedHitSize => widget.hitSize ?? widget.size + 12;

  ShellInputPolicy _policy(BuildContext context) =>
      ShellScope.maybeOf(context)?.inputPolicy ?? ShellInputPolicy.desktop;

  bool _activeFor(ShellInputPolicy policy) =>
      (policy.scaleOnHover && _hover) || (policy.scaleOnFocus && _focused);

  Color _resolveIconColor(ShellInputPolicy policy) {
    if (widget.color != null) {
      return _activeFor(policy)
          ? ForjaShellColors.iconHover
          : widget.color!;
    }
    return _activeFor(policy)
        ? ForjaShellColors.iconHover
        : ForjaShellColors.iconMuted;
  }

  Color _resolveFillColor() {
    final fillAlpha = _pressed ? 0.14 : 0.10;
    return Colors.white.withValues(alpha: fillAlpha);
  }

  double _scaleFor(ShellInputPolicy policy) {
    if (_pressed) return widget.pressScale;
    if (_activeFor(policy)) return widget.hoverScale;
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final policy = _policy(context);
    final showFill = _activeFor(policy) || _pressed;

    Widget button = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _pressed = false;
      }),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: widget.onTap != null
            ? (_) => setState(() => _pressed = true)
            : null,
        onTapUp: widget.onTap != null
            ? (_) => setState(() => _pressed = false)
            : null,
        onTapCancel:
            widget.onTap != null ? () => setState(() => _pressed = false) : null,
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _scaleFor(policy),
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: SizedBox(
            width: _resolvedHitSize,
            height: _resolvedHitSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: showFill ? _resolveFillColor() : Colors.transparent,
              ),
              child: Center(
                child: widget.child ??
                    Icon(
                      widget.icon,
                      size: widget.size,
                      color: _resolveIconColor(policy),
                    ),
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.onTap != null) {
      button = Focus(
        focusNode: widget.focusNode,
        debugLabel: widget.focusNode?.debugLabel ?? 'forja-plain-icon',
        onFocusChange: (focused) => setState(() => _focused = focused),
        onKeyEvent: (node, event) {
          final custom = widget.onKeyEvent?.call(node, event);
          if (custom == KeyEventResult.handled) return KeyEventResult.handled;
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.select) {
            widget.onTap!();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: button,
      );
    }

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: button);
    }
    return button;
  }
}

/// Borderless dismiss control — soft circular fill on hover, no outline.
class ForjaCloseButton extends StatelessWidget {
  const ForjaCloseButton({
    super.key,
    this.onTap,
    this.tooltip = 'Close',
    this.color,
    this.size = 20,
    this.hitSize = 36,
    this.compact = false,
  });

  const ForjaCloseButton.compact({
    super.key,
    this.onTap,
    this.tooltip = 'Close',
    this.color,
    this.size = 18,
    this.hitSize = 32,
  }) : compact = true;

  final VoidCallback? onTap;
  final String? tooltip;
  final Color? color;
  final double size;
  final double hitSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ForjaPlainIcon(
      icon: Icons.close_rounded,
      tooltip: tooltip,
      color: color,
      size: size,
      hitSize: hitSize,
      onTap: onTap,
    );
  }
}

/// Bordered square icon — use sparingly; prefer [ForjaPlainIcon] in hero chrome.
class ForjaIconButton extends StatelessWidget {
  const ForjaIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = ShellTokens.shellButtonHeight,
    this.tooltip,
    this.child,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final String? tooltip;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    const borderColor = ForjaShellColors.ghostBorder;
    const iconColor = ForjaShellColors.textPrimary;

    final button = ForjaInteractive(
      onTap: onTap,
      hoverScale: 1.08,
      pressScale: 0.95,
      builder: (hover, pressed) {
        return Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ShellTokens.shellButtonRadius),
            border: Border.all(
              color: hover ? iconColor.withValues(alpha: 0.5) : borderColor,
            ),
          ),
          child: child ?? Icon(icon, size: 20, color: iconColor),
        );
      },
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}
