import 'package:flutter/material.dart';
import 'package:forja/shell/focus/shell_focusable_tap.dart';
import 'package:forja/shell/core/forja_shell_input_policy.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

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
      ForjaShellColors.cinematic.chromeIconIdle;

  @override
  State<ShellBackIconButton> createState() => _ShellBackIconButtonState();
}

class _ShellBackIconButtonState extends State<ShellBackIconButton> {
  final ValueNotifier<bool> _hoveredN = ValueNotifier(false);
  bool _focused = false;

  @override
  void dispose() {
    _hoveredN.dispose();
    super.dispose();
  }

  void _setHovered(bool hovered) {
    if (_hoveredN.value == hovered) return;
    _hoveredN.value = hovered;
  }

  bool _activeFor(bool hovered) {
    final policy = ShellScope.inputPolicyOf(context);
    return ShellInputPolicy.interactiveActive(
      policy,
      hovered: hovered,
      focused: _focused,
      context: context,
    );
  }

  Color get _idle =>
      widget.idleColor ?? ShellBackIconButton.defaultIdle(context);

  Widget _buildBody(bool hovered) {
    final resolvedHit = widget.hitSize ?? widget.size + 12;
    final active = _activeFor(hovered);
    final fg = active
        ? ForjaShellColors.cinematic.chromeIconActive
        : _idle;
    final fillAlpha = active ? 0.10 : 0.0;

    return SizedBox(
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
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return const SizedBox.shrink();

    final resolvedHit = widget.hitSize ?? widget.size + 12;
    final button = shellFocusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: resolvedHit / 2,
      scaleOnFocus: 1.0,
      suppressInkHover: true,
      focusNode: widget.focusNode,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onHoverChange: _setHovered,
      child: ListenableBuilder(
        listenable: _hoveredN,
        builder: (context, _) => _buildBody(_hoveredN.value),
      ),
    );

    if (widget.tooltip == null) return button;
    return Tooltip(message: widget.tooltip!, child: button);
  }
}
