import 'package:flutter/material.dart';
import 'package:forja_foundation/components/network_image.dart';
import 'package:forja_foundation/tokens/forja_details_tokens.dart';
import 'package:forja_foundation/tokens/forja_motion_theme.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/horizontal_scroller.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/details/hero_pill_surfaces.dart';

/// One trailer card — absolute thumbnail URL + title (props only).
class DetailsTrailerItem {
  const DetailsTrailerItem({
    required this.key,
    required this.name,
    required this.thumbnailUrl,
    this.official = false,
  });

  final String key;
  final String name;
  final String thumbnailUrl;
  final bool official;
}

/// Horizontal trailers row — same gutters / scroller as Home catalog rails.
class DetailsTrailersSection extends StatelessWidget {
  const DetailsTrailersSection({
    super.key,
    required this.trailers,
    required this.onTap,
    this.title = 'Trailers',
    this.outdentHorizontal = 0,
    this.itemBuilder,
  });

  final List<DetailsTrailerItem> trailers;
  final void Function(int index) onTap;
  final String title;
  /// Cancels parent horizontal padding so row insets match home catalog rows.
  final double outdentHorizontal;
  final Widget Function(
    BuildContext context, {
    required int index,
    required Widget child,
  })? itemBuilder;

  @override
  Widget build(BuildContext context) {
    if (trailers.isEmpty) return const SizedBox.shrink();

    final tv = ShellPaintScope.usesTvDensityOf(context);
    final cardWidth = tv
        ? DetailsTokens.trailerCardWidthTv
        : DetailsTokens.trailerCardWidth;
    final titleGap = tv
        ? DetailsTokens.sectionTitleGapTv
        : DetailsTokens.sectionTitleGap;
    final playOverlay = heroPillHeightOf(context);
    final titleStyle = TextStyle(
      color: Colors.white,
      fontSize: tv
          ? DetailsTokens.sectionTitleFontSizeTv
          : ShellTokens.sectionTitleFontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: ShellTokens.sectionTitleLetterSpacing,
    );
    const homePad = ShellTokens.homeSectionHorizontalPadding;
    final thumbHeight = cardWidth * 9 / 16;
    const textBlock = 8 + 12 * 1.25 * 2;
    final trailerRowHeight =
        thumbHeight * ForjaMotionTheme.defaults.cardLift.focusScale + textBlock + 4;
    final outdent = outdentHorizontal;

    final row = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            homePad,
            0,
            homePad,
            titleGap,
          ),
          child: Text(title, style: titleStyle),
        ),
        FocusTraversalGroup(
          child: HorizontalScroller(
            height: trailerRowHeight,
            padding: const EdgeInsets.symmetric(horizontal: homePad),
            itemCount: trailers.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: ShellTokens.posterCardRowGap),
            itemBuilder: (context, index) {
              final trailer = trailers[index];
              final thumb = ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: cardWidth,
                  height: thumbHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ForjaNetworkImage(
                        url: trailer.thumbnailUrl,
                        fit: BoxFit.cover,
                        error: ColoredBox(
                          color: Colors.white.withValues(alpha: 0.06),
                          child: const Icon(
                            Icons.movie_outlined,
                            color: Colors.white24,
                          ),
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.45),
                            ],
                          ),
                        ),
                      ),
                      Center(
                        child: Container(
                          width: playOverlay,
                          height: playOverlay,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.black,
                            size: 26,
                          ),
                        ),
                      ),
                      if (trailer.official)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Official',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
              final tappable = itemBuilder != null
                  ? itemBuilder!(
                      context,
                      index: index,
                      child: thumb,
                    )
                  : ShellPaintScope.focusableTap(
                      context: context,
                      onTap: () => onTap(index),
                      borderRadius: 10,
                      showFocusBorder: true,
                      showFocusFill: false,
                      listIndex: index,
                      motion: ForjaMotionPreset.cardLift,
                      child: thumb,
                    );
              return SizedBox(
                width: cardWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    tappable,
                    const SizedBox(height: 8),
                    Text(
                      trailer.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );

    if (outdent <= 0) return row;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth + outdent * 2,
          child: Transform.translate(
            offset: Offset(-outdent, 0),
            child: row,
          ),
        );
      },
    );
  }
}
