import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';

/// Constrained, padded column below the full-bleed media details hero.
/// Pulls up under the hero on a flat shell background (no backdrop blur).
class MediaDetailsBody extends StatelessWidget {
  const MediaDetailsBody({
    super.key,
    required this.child,
    this.backgroundColor,
    this.bodyOverlap,
    this.topSpacing,
  });

  final Widget child;
  final Color? backgroundColor;
  final double? bodyOverlap;
  final double? topSpacing;

  Color _shellBg(BuildContext context) {
    return backgroundColor ?? AppTheme.bgDark;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final inset = ShellTokens.detailsContentHorizontalPadding(width);
    final shellBg = _shellBg(context);
    final overlap = bodyOverlap ?? ShellTokens.detailsHeroBodyOverlap;
    final top = topSpacing ?? ShellTokens.detailsBodyTopSpacing;

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
                    top,
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
