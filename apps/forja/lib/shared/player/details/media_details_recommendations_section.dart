import 'package:flutter/material.dart';
import 'package:forja/shared/shell/core/forja_shell_layout.dart';
import 'package:forja/shared/shell/tv/shell_tv_focus.dart';
import 'package:forja/shared/shell/tv/tv_focus_graph.dart';
import 'package:forja/shared/engine/runtime/kit/pack_layout_capabilities.dart' show PackLayoutMovie;
import 'package:forja/shared/engine/runtime/kit/pack_layout_host_wire.dart' show MoviePosterCard;
import 'package:forja_foundation/widgets/details/recommendations_section.dart';
import 'package:rust/rust.dart';

PackLayoutMovie _packMovie(Movie m) => PackLayoutMovie(
      id: m.id,
      title: m.title,
      posterPath: m.posterPath,
      backdropPath: m.backdropPath,
      logoPath: m.logoPath,
      voteAverage: m.voteAverage,
      releaseDate: m.releaseDate,
      overview: m.overview,
      genres: m.genres,
      mediaType: m.mediaType,
    );

/// Host wire — maps [Movie] posters into foundation [DetailsRecommendationsSection].
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

    final paint = DetailsRecommendationsSection(
      title: title,
      rowHeight: MoviePosterCard.cardHeight(context),
      gap: shellPosterCardRowGap(context),
      cards: [
        for (var i = 0; i < movies.length; i++)
          MoviePosterCard(
            movie: _packMovie(movies[i]),
            onTap: () => onMovieTap(movies[i]),
            listIndex: i,
            tvTabId: tabId,
            tvRowId: rowId,
          ),
      ],
    );

    return TvKitRow(
      tabId: tabId,
      rowId: rowId,
      sortOrder: tvRowOrder,
      itemCount: movies.length,
      onFocusUp: tvFocusUp,
      child: paint,
    );
  }
}
