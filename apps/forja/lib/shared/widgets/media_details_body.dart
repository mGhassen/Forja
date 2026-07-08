import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart' hide AppTheme;
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/media_details_backdrop.dart';

/// Constrained, padded column below the full-bleed media details hero.
/// Pulls up under the hero with a blurred backdrop bridge so scroll feels continuous.
class MediaDetailsBody extends StatelessWidget {
  const MediaDetailsBody({
    super.key,
    required this.child,
    this.backdropUrl,
    this.backgroundColor,
  });

  final Widget child;
  final String? backdropUrl;
  final Color? backgroundColor;

  Color _shellBg(BuildContext context) {
    return backgroundColor ??
        (AppTheme.isLightMode
            ? AppTheme.appBackground
            : Theme.of(context).scaffoldBackgroundColor);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final inset = ShellTokens.detailsContentHorizontalPadding(width);
    final shellBg = _shellBg(context);
    final overlap = ShellTokens.detailsHeroBodyOverlap;

    return Transform.translate(
      offset: Offset(0, -overlap),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: MediaDetailsBackdropScrim(
              imageUrl: backdropUrl,
              fallbackColor: shellBg,
              blurSigma: 42,
              gradientStops: const [0.0, 0.1, 0.28, 0.55, 0.82, 1.0],
              gradientColors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.18),
                Colors.black.withValues(alpha: 0.42),
                Colors.black.withValues(alpha: 0.68),
                Colors.black.withValues(alpha: 0.88),
                Colors.black.withValues(alpha: 0.96),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: overlap),
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: ShellTokens.bodyMaxWidthDesktop,
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      inset,
                      ShellTokens.detailsBodyTopSpacing,
                      inset,
                      ShellTokens.detailsBodyBottomSpacing,
                    ),
                    child: child,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
