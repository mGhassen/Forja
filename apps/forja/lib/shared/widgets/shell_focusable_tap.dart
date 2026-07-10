import 'package:flutter/material.dart';

import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';

/// TV: [FocusableControl] with D-pad focus lift. Phone/desktop: plain [InkWell].
Widget shellFocusableTap({
  required BuildContext context,
  required Widget child,
  VoidCallback? onTap,
  double borderRadius = 12,
  double scaleOnFocus = ShellTokens.focusActiveScale,
  VoidCallback? onLeftEdge,
  VoidCallback? onUpEdge,
}) {
  final policy = ShellScope.inputPolicyOf(context);
  if (policy.useFocusableMoodChips) {
    return FocusableControl(
      onTap: onTap,
      borderRadius: borderRadius,
      scaleOnFocus: scaleOnFocus,
      onLeftEdge: onLeftEdge,
      onUpEdge: onUpEdge,
      child: child,
    );
  }
  return Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(borderRadius),
    child: InkWell(
      borderRadius: BorderRadius.circular(borderRadius),
      onTap: onTap,
      child: child,
    ),
  );
}
