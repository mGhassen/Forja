import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart' hide AppTheme;
import 'package:forja/shared/theme/app_theme.dart';

/// Constrained, padded column below the full-bleed media details hero.
/// Pulls up under the hero on a flat shell background (no backdrop blur).
class MediaDetailsBody extends StatelessWidget {
  const MediaDetailsBody({
    super.key,
    required this.child,
    this.backgroundColor,
  });

  final Widget child;
  final Color? backgroundColor;

  Color _shellBg(BuildContext context) {
    return backgroundColor ?? AppTheme.bgDark;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final inset = ShellTokens.detailsContentHorizontalPadding(width);
    final shellBg = _shellBg(context);
    final overlap = ShellTokens.detailsHeroBodyOverlap;

    return Transform.translate(
      offset: Offset(0, -overlap),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: overlap),
          ColoredBox(
            color: shellBg,
            child: Align(
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
          ),
        ],
      ),
    );
  }
}
