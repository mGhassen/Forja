import 'package:flutter/material.dart';
import 'package:forja/shared/design/src/forja_shell_colors.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:forja/shared/theme/app_theme.dart';
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

  Color get _color {
    if (AppTheme.isLightMode) return Colors.black87;
    return ForjaShellColors.textPrimary;
  }

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

/// Bare icon action — no background, scales on hover.
class ForjaPlainIcon extends StatelessWidget {
  const ForjaPlainIcon({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.color,
    this.size = 24,
    this.hoverScale = 1.12,
    this.pressScale = 0.94,
    this.child,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final Color? color;
  final double size;
  final double hoverScale;
  final double pressScale;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final button = ForjaInteractive(
      onTap: onTap,
      hoverScale: hoverScale,
      pressScale: pressScale,
      builder: (hover, pressed) {
        final resolved = color ??
            (AppTheme.isLightMode
                ? (hover ? Colors.black87 : Colors.black54)
                : hover
                    ? ForjaShellColors.iconHover
                    : ForjaShellColors.iconMuted);
        return Padding(
          padding: const EdgeInsets.all(8),
          child: child ??
              Icon(
                icon,
                size: size,
                color: resolved,
              ),
        );
      },
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

/// Borderless dismiss control — soft circular fill on hover, no outline.
class ForjaCloseButton extends StatefulWidget {
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
  State<ForjaCloseButton> createState() => _ForjaCloseButtonState();
}

class _ForjaCloseButtonState extends State<ForjaCloseButton> {
  bool _hover = false;
  bool _pressed = false;

  Color _resolveIconColor() {
    return widget.color ??
        (AppTheme.isLightMode
            ? (_hover ? Colors.black87 : Colors.black54)
            : _hover
                ? ForjaShellColors.cinematic.textPrimary
                : ForjaShellColors.cinematic.textSecondary);
  }

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? 0.94 : (_hover ? 1.08 : 1.0);
    final fillAlpha = _pressed ? 0.14 : 0.10;
    final fillColor = AppTheme.isLightMode
        ? Colors.black.withValues(alpha: fillAlpha)
        : Colors.white.withValues(alpha: fillAlpha);

    final button = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _pressed = false;
      }),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          width: widget.hitSize,
          height: widget.hitSize,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.onTap,
              onHighlightChanged: (pressed) =>
                  setState(() => _pressed = pressed),
              hoverColor: fillColor,
              splashColor: fillColor,
              highlightColor: fillColor,
              child: Icon(
                Icons.close_rounded,
                size: widget.size,
                color: _resolveIconColor(),
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
    final borderColor = AppTheme.isLightMode
        ? Colors.black26
        : ForjaShellColors.ghostBorder;
    final iconColor = AppTheme.isLightMode
        ? Colors.black87
        : ForjaShellColors.textPrimary;

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
