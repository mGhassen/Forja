import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja/shared/shell/forja_interactive.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/components/button.dart';

export 'package:forja/shared/shell/forja_interactive.dart';

/// Text-only CTA - no border, no filled background.
///
/// Delegates to package [Button] (RFC-106 G14-B) — same constructor API.
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

  @override
  Widget build(BuildContext context) {
    return Button(
      variant: ButtonVariant.ghost,
      label: label,
      icon: icon,
      onPressed: onTap,
      autofocus: autoFocus,
      focusNode: focusNode,
    );
  }
}

/// Bare icon action — package [Button] `plainIcon`.
class ForjaPlainIcon extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Button(
      variant: ButtonVariant.plainIcon,
      size: ButtonSize.icon,
      icon: icon,
      onPressed: onTap,
      tooltip: tooltip,
      color: color,
      iconSize: size,
      height: hitSize,
      focusNode: focusNode,
      onKeyEvent: onKeyEvent,
    );
  }
}

/// Top-bar action icon that matches the shell menu tabs (Films / TV Shows …):
/// idles at [ForjaShellColors.textSecondary] and animates to white on
/// hover/focus with **no** background fill - same color language as the tabs.
class ForjaTopBarIcon extends StatefulWidget {
  const ForjaTopBarIcon({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.size = 24,
    this.hitSize,
    this.focusNode,
    this.onFocusChange,
    this.manageFocus = true,
    this.highlighted,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final double? hitSize;
  final FocusNode? focusNode;
  final ValueChanged<bool>? onFocusChange;

  /// When false, skip owning a [Focus] (parent already focuses, e.g. TV tap).
  final bool manageFocus;

  /// External highlight (TV focus from parent). Combined with hover/focus.
  final bool? highlighted;

  @override
  State<ForjaTopBarIcon> createState() => _ForjaTopBarIconState();
}

class _ForjaTopBarIconState extends State<ForjaTopBarIcon> {
  static const _animDuration = Duration(milliseconds: 280);
  static const _animCurve = Curves.easeInOutCubic;

  bool _hover = false;
  bool _focused = false;

  double get _resolvedHitSize => widget.hitSize ?? widget.size + 12;

  @override
  Widget build(BuildContext context) {
    final active = _hover || _focused || (widget.highlighted == true);
    final idle = ForjaShellColors.cinematic.textSecondary;

    Widget button = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: _resolvedHitSize,
          height: _resolvedHitSize,
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: active ? 1 : 0),
              duration: _animDuration,
              curve: _animCurve,
              builder: (context, t, _) {
                return Icon(
                  widget.icon,
                  size: widget.size,
                  color: Color.lerp(idle, Colors.white, t),
                );
              },
            ),
          ),
        ),
      ),
    );

    if (widget.onTap != null && widget.manageFocus) {
      button = Focus(
        focusNode: widget.focusNode,
        debugLabel: widget.focusNode?.debugLabel ?? 'forja-top-bar-icon',
        onFocusChange: (focused) {
          setState(() => _focused = focused);
          widget.onFocusChange?.call(focused);
        },
        onKeyEvent: (node, event) {
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

/// Borderless dismiss control - soft circular fill on hover, no outline.
class ForjaCloseButton extends StatelessWidget {
  const ForjaCloseButton({
    super.key,
    this.onTap,
    this.tooltip = 'Close',
    this.color,
    this.size = 20,
    this.hitSize = 36,
    this.compact = false,
    this.focusNode,
    this.onKeyEvent,
  });

  const ForjaCloseButton.compact({
    super.key,
    this.onTap,
    this.tooltip = 'Close',
    this.color,
    this.size = 18,
    this.hitSize = 32,
    this.focusNode,
    this.onKeyEvent,
  }) : compact = true;

  final VoidCallback? onTap;
  final String? tooltip;
  final Color? color;
  final double size;
  final double hitSize;
  final bool compact;
  final FocusNode? focusNode;
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;

  @override
  Widget build(BuildContext context) {
    return Button(
      variant: ButtonVariant.plainIcon,
      size: ButtonSize.icon,
      icon: Icons.close_rounded,
      compact: compact,
      tooltip: tooltip,
      color: color,
      iconSize: size,
      height: hitSize,
      onPressed: onTap,
      focusNode: focusNode,
      onKeyEvent: onKeyEvent,
    );
  }
}

/// Bordered square icon - use sparingly; prefer [ForjaPlainIcon] in hero chrome.
///
/// Delegates to package [Button] when [child] is null (RFC-106 G14-B).
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
    if (child == null) {
      return Button(
        variant: ButtonVariant.outline,
        size: ButtonSize.icon,
        icon: icon,
        onPressed: onTap,
        tooltip: tooltip,
      );
    }

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
