import 'package:flutter/material.dart';
import 'package:forja/shared/design/src/forja_shell_colors.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

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

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.isLightMode
        ? Colors.black87
        : ForjaShellColors.textPrimary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 22, color: color),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    final iconColor = color ??
        (AppTheme.isLightMode
            ? Colors.black54
            : ForjaShellColors.iconMuted);

    final content = Padding(
      padding: const EdgeInsets.all(8),
      child: child ?? Icon(icon, size: size, color: iconColor),
    );

    final button = onTap != null
        ? InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
            child: content,
          )
        : content;

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
