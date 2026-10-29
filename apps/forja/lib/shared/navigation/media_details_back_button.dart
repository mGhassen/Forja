import 'dart:io';

import 'package:flutter/material.dart';
import 'package:forja/shell/routing/shell_overlay_navigator.dart';
import 'package:forja/shared/navigation/shell_back_icon_button.dart';
import 'package:forja_foundation/tokens/forja_details_tokens.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/details/details_top_bar.dart';

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
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final iconSize = DetailsTokens.backIconSizeOf(tv);
    final hitSize = DetailsTokens.backHitSizeOf(tv);
    return Positioned(
      top: topInset(context),
      left: 0,
      right: 0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inset = DetailsTokens.contentLeftInset(constraints.maxWidth);
          final rtl = Directionality.of(context) == TextDirection.rtl;
          return Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: EdgeInsetsDirectional.only(start: inset),
              child: ShellBackIconButton(
                icon: rtl
                    ? Icons.chevron_right_rounded
                    : Icons.chevron_left_rounded,
                size: iconSize,
                hitSize: hitSize,
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

/// Phone details top bar: 48 dp back control on a scrim, then a solid bar
/// with the title once the hero has scrolled away.
///
/// [heroKey] sits on the hero so the fade tracks its real height (the phone
/// hero grows with its content).
class MediaDetailsMobileTopBar extends StatelessWidget {
  const MediaDetailsMobileTopBar({
    super.key,
    required this.scrollController,
    required this.heroKey,
    required this.title,
    required this.backgroundColor,
    this.focusNode,
    this.onPressed,
  });

  final ScrollController scrollController;
  final GlobalKey heroKey;
  final String title;
  final Color backgroundColor;
  final FocusNode? focusNode;
  final VoidCallback? onPressed;

  double _progress(BuildContext context) {
    if (!scrollController.hasClients) return 0;
    // Render box, not Element.size — that getter asserts during build.
    final box = heroKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return 0;
    final heroHeight = box.size.height;
    if (heroHeight <= 0) return 0;
    final barBottom =
        MediaQuery.paddingOf(context).top + DetailsTokens.topBarHeightMobile;
    // Solid exactly when the hero bottom reaches the bar bottom.
    final solidAt = heroHeight - barBottom;
    final fadeStart = solidAt - DetailsTokens.topBarFadeDistance;
    final offset = scrollController.offset;
    if (offset <= fadeStart) return 0;
    if (offset >= solidAt) return 1;
    return (offset - fadeStart) / DetailsTokens.topBarFadeDistance;
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return AnimatedBuilder(
      animation: scrollController,
      builder: (context, _) {
        final progress = _progress(context);
        return DetailsCollapsingTopBar(
          progress: progress,
          title: title,
          backgroundColor: backgroundColor,
          leading: DetailsBackScrim(
            color: backgroundColor,
            opacity: 1 - progress,
            child: ShellBackIconButton(
              icon: rtl
                  ? Icons.chevron_right_rounded
                  : Icons.chevron_left_rounded,
              size: DetailsTokens.backIconSizeMobile,
              hitSize: DetailsTokens.backHitSizeMobile,
              idleColor: ForjaShellColors.cinematic.chromeIconActive,
              tooltip: 'Back',
              focusNode: focusNode,
              onTap:
                  onPressed ?? () => MediaDetailsBackButton.popDetails(context),
            ),
          ),
        );
      },
    );
  }
}
