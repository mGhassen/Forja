import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';

/// Scales on hover/focus with a flat cinematic shadow (no colored glow).
/// Uses [shellFocusableTap] for D-pad focus lift + thin white focus border.
class HoverScale extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final double radius;

  const HoverScale({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.scale = ShellTokens.focusActiveScale,
    this.radius = 14,
  });

  @override
  Widget build(BuildContext context) {
    final tap = shellFocusableTap(
      context: context,
      onTap: onTap,
      borderRadius: radius,
      scaleOnFocus: scale,
      showFocusBorder: true,
      child: child,
    );
    if (onLongPress == null) return tap;
    return GestureDetector(
      onLongPress: onLongPress,
      behavior: HitTestBehavior.deferToChild,
      child: tap,
    );
  }
}
