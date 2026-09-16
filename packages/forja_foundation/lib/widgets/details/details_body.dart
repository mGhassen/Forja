import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_theme_extension.dart';
import 'package:forja_foundation/tokens/forja_details_tokens.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Constrained column below the full-bleed media details hero.
///
/// Horizontal inset is **not** applied here — catalog rows are edge-to-edge;
/// wrap text-only blocks in [padContent].
///
/// When [bodyOverlap] > 0, the body is translated up onto the hero backdrop
/// (no solid fill in that band — backdrop + soft gradient stay visible).
class DetailsBody extends StatelessWidget {
  const DetailsBody({
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

  @override
  Widget build(BuildContext context) {
    final shellBg =
        backgroundColor ?? ForjaThemeExtension.of(context).bgDark;
    final overlap = bodyOverlap ?? DetailsTokens.heroBodyOverlap;
    final top = topSpacing ?? DetailsTokens.bodyTopSpacing;

    final content = Align(
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
    );

    if (overlap > 0) {
      // Translate paints the first row onto the backdrop. Add matching bottom
      // extent so end-of-scroll doesn't leave a blank overlap-sized hole.
      return Transform.translate(
        offset: Offset(0, -overlap),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            content,
            ColoredBox(
              color: shellBg,
              child: SizedBox(height: overlap, width: double.infinity),
            ),
          ],
        ),
      );
    }

    return ColoredBox(color: shellBg, child: content);
  }
}

/// Host alias — same paint as [DetailsBody].
typedef MediaDetailsBody = DetailsBody;
