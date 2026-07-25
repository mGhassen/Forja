import 'package:flutter/material.dart';

import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';

/// Muted back icon that turns white on hover or D-pad focus (cinematic overlays).
class ShellBackIconButton extends StatefulWidget {
  const ShellBackIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 24,
    this.hitSize,
    this.tooltip = 'Back',
    this.focusNode,
    this.idleColor,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double? hitSize;
  final String? tooltip;
  final FocusNode? focusNode;
  final Color? idleColor;

  static Color defaultIdle(BuildContext context) =>
      Colors.white.withValues(alpha: 0.54);

  @override
  State<ShellBackIconButton> createState() => _ShellBackIconButtonState();
}

class _ShellBackIconButtonState extends State<ShellBackIconButton> {
  bool _hovered = false;
  bool _focused = false;

  bool get _active {
    final policy = ShellScope.inputPolicyOf(context);
    return ShellInputPolicy.interactiveActive(
      policy,
      hovered: _hovered,
      focused: _focused,
    );
  }

  Color get _idle =>
      widget.idleColor ?? ShellBackIconButton.defaultIdle(context);

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return const SizedBox.shrink();

    final resolvedHit = widget.hitSize ?? widget.size + 12;
    final fg = _active ? Colors.white : _idle;
    final fillAlpha = _active ? 0.10 : 0.0;

    // Full hit box must stay hittable - Align+smaller child made most of the
    // target miss with GestureDetector's default deferToChild behavior.
    final body = SizedBox(
      width: resolvedHit,
      height: resolvedHit,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: fillAlpha),
        ),
        child: Center(
          child: Icon(widget.icon, size: widget.size, color: fg),
        ),
      ),
    );

    final button = shellFocusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: resolvedHit / 2,
      scaleOnFocus: 1.0,
      suppressInkHover: true,
      focusNode: widget.focusNode,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onHoverChange: (hovered) => setState(() => _hovered = hovered),
      child: body,
    );

    if (widget.tooltip == null) return button;
    return Tooltip(message: widget.tooltip!, child: button);
  }
}
