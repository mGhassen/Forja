import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_details_tokens.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Phone details top bar: transparent over the hero, solid with the title
/// once the hero scrolls away. Paint only — host drives [progress] from its
/// scroll position and passes the back control as [leading].
class DetailsCollapsingTopBar extends StatelessWidget {
  const DetailsCollapsingTopBar({
    super.key,
    required this.progress,
    required this.title,
    required this.leading,
    required this.backgroundColor,
  });

  /// 0 = transparent over the hero, 1 = solid bar with title.
  final double progress;
  final String title;
  final Widget leading;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final t = progress.clamp(0.0, 1.0);
    final topInset = MediaQuery.paddingOf(context).top;
    final solid = t >= 1;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: topInset + DetailsTokens.topBarHeightMobile,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Solid bar absorbs taps so content under it is not hit by mistake.
          IgnorePointer(
            ignoring: !solid,
            child: ColoredBox(color: backgroundColor.withValues(alpha: t)),
          ),
          Padding(
            padding: EdgeInsetsDirectional.only(
              top: topInset,
              start: DetailsTokens.topBarTitleGap,
              end: DetailsTokens.backHitSizeMobile,
            ),
            child: Row(
              children: [
                leading,
                const SizedBox(width: DetailsTokens.topBarTitleGap),
                Expanded(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: t,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ForjaShellColors.textPrimary,
                          fontSize: DetailsTokens.detailsHeaderFontSize,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Round scrim behind a back chevron so it reads over bright backdrops.
class DetailsBackScrim extends StatelessWidget {
  const DetailsBackScrim({
    super.key,
    required this.child,
    required this.color,
    this.opacity = 1,
  });

  final Widget child;

  /// Scrim base color (host passes the theme background).
  final Color color;

  /// Fades the scrim out as the solid top bar fades in.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(
          alpha: DetailsTokens.backScrimAlpha * opacity.clamp(0.0, 1.0),
        ),
      ),
      child: child,
    );
  }
}
