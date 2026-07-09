import 'package:flutter/material.dart';
import 'package:forja/shared/design/src/forja_shell_colors.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:google_fonts/google_fonts.dart';

typedef ForjaInteractiveBuilder = Widget Function(bool hover, bool pressed);

class ForjaInteractive extends StatefulWidget {
  const ForjaInteractive({
    super.key,
    required this.builder,
    this.onTap,
    this.hoverScale = 1.06,
    this.pressScale = 0.94,
  });

  final ForjaInteractiveBuilder builder;
  final VoidCallback? onTap;
  final double hoverScale;
  final double pressScale;

  @override
  State<ForjaInteractive> createState() => _ForjaInteractiveState();
}

class _ForjaInteractiveState extends State<ForjaInteractive> {
  bool _hover = false;
  bool _pressed = false;

  double get _scale {
    if (_pressed) return widget.pressScale;
    if (_hover) return widget.hoverScale;
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final body = AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      child: widget.builder(_hover, _pressed),
    );

    return MouseRegion(
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
  }
}

/// Text-only CTA — no border, no filled background.
class ForjaGhostButton extends StatelessWidget {
  const ForjaGhostButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  Color get _color => ForjaShellColors.textPrimary;

  @override
  Widget build(BuildContext context) {
    return ForjaInteractive(
      onTap: onTap,
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

/// Bare icon action — soft circular fill on hover/press, no border.
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

  @override
  State<ForjaPlainIcon> createState() => _ForjaPlainIconState();
}

class _ForjaPlainIconState extends State<ForjaPlainIcon> {
  bool _hover = false;
  bool _pressed = false;

  double get _resolvedHitSize => widget.hitSize ?? widget.size + 12;

  Color _resolveIconColor() {
    return widget.color ??
        (_hover ? ForjaShellColors.iconHover : ForjaShellColors.iconMuted);
  }

  Color _resolveFillColor() {
    final fillAlpha = _pressed ? 0.14 : 0.10;
    return Colors.white.withValues(alpha: fillAlpha);
  }

  @override
  Widget build(BuildContext context) {
    final scale = _pressed
        ? widget.pressScale
        : (_hover ? widget.hoverScale : 1.0);
    final showFill = _hover || _pressed;

    final button = MouseRegion(
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
          scale: scale,
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
                      color: _resolveIconColor(),
                    ),
              ),
            ),
          ),
        ),
      ),
    );

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
