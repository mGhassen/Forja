import 'dart:io';

import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/navigation/shell_back_icon_button.dart';

/// Floating chevron back control for media details — sits below macOS traffic lights.
class MediaDetailsBackButton extends StatelessWidget {
  const MediaDetailsBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  static double topInset(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final isDesktop =
        Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    if (isDesktop) return top + 16;
    return top + 10;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: topInset(context),
      left: ShellTokens.detailsBackButtonLeftInset(context),
      child: ShellBackIconButton(
        icon: Icons.chevron_left_rounded,
        size: 28,
        tooltip: 'Back',
        onTap: onPressed ?? () => Navigator.maybePop(context),
      ),
    );
  }
}
