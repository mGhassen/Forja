import 'package:flutter/material.dart';
import 'package:forja/shared/design/src/forja_shell_colors.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

typedef ForjaInteractiveBuilder = Widget Function(bool hover, bool pressed);

class _ForjaInteractive extends StatefulWidget {
  const _ForjaInteractive({
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
  State<_ForjaInteractive> createState() => _ForjaInteractiveState();
}

class _ForjaInteractiveState extends State<_ForjaInteractive> {
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

  Color _color(bool hover, bool pressed) {
    if (AppTheme.isLightMode) {
      return hover || pressed ? Colors.black : Colors.black87;
    }
    if (hover || pressed) return Colors.white;
    return ForjaShellColors.textPrimary;
  }

  @override
  Widget build(BuildContext context) {
    return _ForjaInteractive(
      onTap: onTap,
      hoverScale: 1.04,
      pressScale: 0.96,
      builder: (hover, pressed) {
        final color = _color(hover, pressed);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 22, color: color),
                const SizedBox(width: 8),
              ],
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOutCubic,
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
                child: Text(label),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Bare icon action — no border box.
class ForjaPlainIcon extends StatelessWidget {
  const ForjaPlainIcon({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.color,
    this.size = 24,
    this.child,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final Color? color;
  final double size;
  final Widget? child;

  Color _iconColor(bool hover, bool pressed) {
    if (color != null) return color!;
    if (AppTheme.isLightMode) {
      return hover || pressed ? Colors.black87 : Colors.black54;
    }
    if (hover || pressed) return ForjaShellColors.textPrimary;
    return ForjaShellColors.iconMuted;
  }

  @override
  Widget build(BuildContext context) {
    final button = _ForjaInteractive(
      onTap: onTap,
      builder: (hover, pressed) {
        return Padding(
          padding: const EdgeInsets.all(8),
          child: child ??
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 140),
                child: Icon(
                  icon,
                  key: ValueKey(_iconColor(hover, pressed)),
                  size: size,
                  color: _iconColor(hover, pressed),
                ),
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

    final content = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ShellTokens.shellButtonRadius),
        border: Border.all(color: borderColor),
      ),
      child: child ?? Icon(icon, size: 20, color: iconColor),
    );

    final button = child != null
        ? content
        : Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius:
                  BorderRadius.circular(ShellTokens.shellButtonRadius),
              child: content,
            ),
          );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}
