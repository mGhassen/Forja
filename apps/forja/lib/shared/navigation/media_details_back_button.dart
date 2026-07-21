import 'dart:io';

import 'package:flutter/material.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/navigation/shell_back_icon_button.dart';

/// Floating chevron back control for media details — sits below macOS traffic lights.
class MediaDetailsBackButton extends StatelessWidget {
  const MediaDetailsBackButton({super.key, this.onPressed, this.focusNode});

  final VoidCallback? onPressed;
  final FocusNode? focusNode;

  static double topInset(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final isDesktop =
        Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    if (isDesktop) return top + 16;
    return top + 10;
  }

  static void popDetails(BuildContext context) {
    if (shellOverlayCanPop()) {
      maybePopShellOverlay();
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: topInset(context),
      left: DetailsTokens.backButtonLeftInset(context),
      child: ShellBackIconButton(
        icon: Icons.chevron_left_rounded,
        size: 28,
        iconAlignment: Alignment.centerLeft,
        tooltip: 'Back',
        focusNode: focusNode,
        onTap: onPressed ?? () => popDetails(context),
      ),
    );
  }
}
