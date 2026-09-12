import 'dart:io';

import 'package:flutter/material.dart';
import 'package:forja/shell/routing/shell_overlay_navigator.dart';
import 'package:forja/shared/navigation/shell_back_icon_button.dart';
import 'package:forja_foundation/tokens/forja_details_tokens.dart';

/// Floating chevron back control for media details - sits below macOS traffic lights.
///
/// Horizontal placement mirrors the details hero title column: centered
/// [ShellTokens.bodyMaxWidthDesktop] band + [DetailsTokens] gutter, measured
/// against the overlay stack width (already rail-inset) — not full-window
/// [MediaQuery], which would double-count the nav rail on wide desktops.
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
      left: 0,
      right: 0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inset = DetailsTokens.contentLeftInset(constraints.maxWidth);
          return Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(left: inset),
              child: ShellBackIconButton(
                icon: Icons.chevron_left_rounded,
                size: 28,
                tooltip: 'Back',
                focusNode: focusNode,
                onTap: onPressed ?? () => popDetails(context),
              ),
            ),
          );
        },
      ),
    );
  }
}
