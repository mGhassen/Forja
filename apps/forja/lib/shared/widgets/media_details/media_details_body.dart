import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';

/// Constrained column below the full-bleed media details hero.
/// Horizontal inset is **not** applied here - catalog rows are edge-to-edge like
/// Home; wrap text-only blocks in [padContent].
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

  /// Standard horizontal inset for synopsis blocks, episode headers, etc.
  static EdgeInsets contentPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final inset = DetailsTokens.contentHorizontalPadding(width);
    return EdgeInsets.symmetric(horizontal: inset);
  }

  static Widget padContent(BuildContext context, Widget child) {
    return Padding(
      padding: contentPadding(context),
      child: child,
    );
  }

  Color _shellBg(BuildContext context) {
    return backgroundColor ?? AppTheme.bgDark;
  }

  @override
  Widget build(BuildContext context) {
    final shellBg = _shellBg(context);
    final overlap = bodyOverlap ?? DetailsTokens.heroBodyOverlap;
    final top = topSpacing ?? DetailsTokens.bodyTopSpacing;

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
                    0,
                    top,
                    0,
                    DetailsTokens.bodyBottomSpacing,
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
