import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_details_tokens.dart';
import 'package:forja/shared/shell/horizontal_scroller.dart';
import 'package:forja/shared/shell/forja_shell_layout.dart';
import 'package:forja/shared/shell/forja_shell_section_title.dart';
import 'package:forja/shared/shell/tv/shell_tv_focus.dart';
import 'package:forja/shared/shell/tv/tv_focus_graph.dart';
import 'package:forja/shared/shell/movie_poster_card.dart';
import 'package:forja_foundation/widgets/catalog/poster_rail.dart';
import 'package:rust/rust.dart';

/// Horizontal "More Like This" row below media details hero.
class MediaDetailsRecommendationsSection extends StatelessWidget {
  const MediaDetailsRecommendationsSection({
    super.key,
    required this.movies,
    required this.onMovieTap,
    this.title = 'More Like This',
    this.tvTabId,
    this.tvRowId,
    this.tvRowOrder = 0,
    this.tvFocusUp,
  });

  final List<Movie> movies;
  final void Function(Movie movie) onMovieTap;
  final String title;
  final String? tvTabId;
  final String? tvRowId;
  final int tvRowOrder;
  final VoidCallback? tvFocusUp;

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) return const SizedBox.shrink();

    final tabId = tvTabId ?? ShellTvFocus.currentNavTabId ?? 'home';
    final rowId = tvRowId ?? 'recommendations';

    return TvKitRow(
      tabId: tabId,
      rowId: rowId,
      sortOrder: tvRowOrder,
      itemCount: movies.length,
      onFocusUp: tvFocusUp,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShellSectionTitle(
            title: title,
            padding: const EdgeInsets.only(
              bottom: DetailsTokens.sectionTitleGap,
            ),
          ),
          FocusTraversalGroup(
            child: HorizontalScroller(
              height: MoviePosterCard.cardHeight(context),
              padding: EdgeInsets.zero,
              itemCount: movies.length,
              separatorBuilder: (_, _) =>
                  SizedBox(width: shellPosterCardRowGap(context)),
              itemBuilder: (context, index) {
                return MoviePosterCard(
                  movie: movies[index],
                  onTap: () => onMovieTap(movies[index]),
                  listIndex: index,
                  tvTabId: tabId,
                  tvRowId: rowId,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Host helper — poster rail from absolute image URLs (no [Movie]).
Widget catalogPosterRail({
  required List<PosterItem> items,
  double itemWidth = 120,
  double itemHeight = 180,
}) {
  return PosterRail(
    items: items,
    itemWidth: itemWidth,
    itemHeight: itemHeight,
  );
}
