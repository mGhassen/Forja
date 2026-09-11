import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Simple focusable tap target — [InkWell] + [Focus].
///
/// Package-level stand-in for host `shellFocusableTap` (TV/graph extras stay
/// in the app until Part 2).
class FocusableTap extends StatelessWidget {
  const FocusableTap({
    super.key,
    required this.onTap,
    required this.child,
    this.focusNode,
    this.autofocus = false,
    this.borderRadius,
    this.enabled = true,
  });

  final VoidCallback? onTap;
  final Widget child;
  final FocusNode? focusNode;
  final bool autofocus;
  final BorderRadius? borderRadius;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        focusNode: focusNode,
        autofocus: autofocus,
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        hoverColor: ForjaShellColors.inkHover,
        splashColor: ForjaShellColors.inkSplash,
        child: child,
      ),
    );
  }
}
