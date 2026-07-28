import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/design/src/details_tokens.dart';
import 'package:forja/shared/design/src/shell_section_title.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/shared/widgets/horizontal_scroller.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:forja/shell/app_router.dart';
import 'package:rust/rust.dart';

const _kTrailerCardWidth = 200.0;

class MediaDetailsTrailersSection extends StatelessWidget {
  const MediaDetailsTrailersSection({
    super.key,
    required this.trailers,
    this.movie,
    this.languageCode,
    this.outdentHorizontal = 0,
    this.tvTabId,
    this.tvRowId,
    this.tvRowOrder = 0,
    this.tvFocusUp,
  });

  final List<MediaTrailer> trailers;
  final Movie? movie;
  final String? languageCode;
  final double outdentHorizontal;
  final String? tvTabId;
  final String? tvRowId;
  final int tvRowOrder;
  final VoidCallback? tvFocusUp;

  @override
  Widget build(BuildContext context) {
    if (trailers.isEmpty) return const SizedBox.shrink();

    final tabId = tvTabId ?? ShellTvFocus.currentNavTabId;
    final rowId = tvRowId ?? 'trailers';

    final outdent = outdentHorizontal;
    final useHomeInsets = outdent > 0;
    final homePad = ShellTokens.homeSectionHorizontalPadding;
    // Catalog focus scale (desktop hover / TV focus) needs vertical room on the thumb only.
    const thumbHeight = _kTrailerCardWidth * 9 / 16;
    const textBlock = 8 + 12 * 1.25 * 2;
    final trailerRowHeight =
        thumbHeight * ShellTokens.focusActiveScale + textBlock + 4;

    final row = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (useHomeInsets)
          ShellSectionTitle(
            title: 'Trailers',
            padding: EdgeInsets.fromLTRB(
              homePad,
              0,
              homePad,
              DetailsTokens.sectionTitleGap,
            ),
          )
        else ...[
          Text('Trailers', style: ShellSectionTitle.titleStyle),
          const SizedBox(height: DetailsTokens.sectionTitleGap),
        ],
        FocusTraversalGroup(
          child: HorizontalScroller(
            height: trailerRowHeight,
            padding: useHomeInsets ? EdgeInsets.only(left: homePad) : EdgeInsets.zero,
            itemCount: trailers.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _TrailerCard(
              trailers: trailers,
              index: index,
              movie: movie,
              languageCode: languageCode,
              tvTabId: tabId,
              tvRowId: tvRowId != null ? rowId : null,
            ),
          ),
        ),
      ],
    );

    final child = outdent <= 0
        ? row
        : LayoutBuilder(
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

    if (tabId == null || tvRowId == null) return child;

    return TvCatalogRow(
      tabId: tabId,
      rowId: rowId,
      sortOrder: tvRowOrder,
      itemCount: trailers.length,
      onFocusUp: tvFocusUp,
      child: child,
    );
  }
}

class _TrailerCard extends StatelessWidget {
  const _TrailerCard({
    required this.trailers,
    required this.index,
    this.movie,
    this.languageCode,
    this.tvTabId,
    this.tvRowId,
  });

  final List<MediaTrailer> trailers;
  final int index;
  final Movie? movie;
  final String? languageCode;
  final String? tvTabId;
  final String? tvRowId;

  MediaTrailer get trailer => trailers[index];

  void _open(BuildContext context) {
    AppRouter.openTrailerPlayer(
      context,
      trailers: trailers,
      initialIndex: index,
      movie: movie,
      languageCode: languageCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final thumbHeight = _kTrailerCardWidth * 9 / 16;

    // Focus ring only on the thumb (poster-card chrome) — not around title text.
    return SizedBox(
      width: _kTrailerCardWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          shellFocusableTap(
            context: context,
            onTap: () => _open(context),
            borderRadius: 10,
            showFocusBorder: true,
            focusBleedWidth: _kTrailerCardWidth,
            listIndex: index,
            tvTabId: tvTabId,
            tvRowId: tvRowId,
            tvItemIndex: index,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: _kTrailerCardWidth,
                height: thumbHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: trailer.youtubeThumbnail,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => ColoredBox(
                        color: Colors.white.withValues(alpha: 0.06),
                        child: const Icon(Icons.movie_outlined, color: Colors.white24),
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
                        width: 40,
                        height: 40,
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
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
            ),
          ),
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
  }
}
