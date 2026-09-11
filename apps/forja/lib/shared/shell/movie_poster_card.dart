import 'package:flutter/material.dart';
import 'package:forja/shared/shell/shell_focusable_tap.dart';
import 'package:forja/shared/shell/forja_shell_layout.dart';
import 'package:forja/shared/player/details/kit_list_status_button.dart';
import 'package:forja_foundation/utils/cover_urls.dart';
import 'package:forja_foundation/widgets/catalog/poster_card.dart';
import 'package:rust/rust.dart' show Movie;

export 'package:forja_foundation/widgets/catalog/poster_card.dart'
    show PosterCard, RatingBadge, RatingBadgeText;

/// Legacy alias for [RatingBadge].
typedef MovieRatingBadge = RatingBadge;

/// Host [Movie] → [PosterCard] mapper (image URL resolved here; no paint).
class MoviePosterCard extends StatelessWidget {
  const MoviePosterCard({
    super.key,
    required this.movie,
    required this.onTap,
    this.rank,
    this.listIndex,
    this.onLeftEdge,
    this.onUpEdge,
    this.tvTabId,
    this.tvRowId,
  });

  final Movie movie;
  final VoidCallback onTap;
  final int? rank;
  final int? listIndex;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onUpEdge;
  final String? tvTabId;
  final String? tvRowId;

  static double cardWidth(BuildContext context) => shellMovieCardWidth(context);

  static double cardHeight(BuildContext context) =>
      shellMovieCardHeight(context);

  static String imageUrlFor(Movie movie) {
    if (movie.posterPath.isEmpty) return '';
    return resolveAbsoluteCoverUrl(movie.posterPath);
  }

  static String metaLine(Movie movie) {
    final parts = <String>[];
    if (movie.releaseDate.isNotEmpty) {
      parts.add(movie.releaseDate.split('-').first);
    }
    if (movie.mediaType == 'tv' || movie.mediaType == 'movie') {
      parts.add(movie.mediaType == 'tv' ? 'TV' : 'FILM');
    }
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final w = MoviePosterCard.cardWidth(context);
    final h = MoviePosterCard.cardHeight(context);
    final radius = shellCardBorderRadius(context);
    final inset = shellScaled(context, 10).clamp(4.0, 10.0);
    final compact = w < 85;
    final pin = !compact
        ? KitListStatusButton.movie(
            movie: movie,
            excludeFromTvTraversal: true,
            iconSize: shellScaled(context, 18).clamp(12.0, 18.0),
          )
        : null;

    return shellFocusableTap(
      context: context,
      onTap: onTap,
      borderRadius: radius,
      showFocusBorder: true,
      listIndex: listIndex,
      onLeftEdge: onLeftEdge,
      onUpEdge: onUpEdge,
      tvTabId: tvTabId,
      tvRowId: tvRowId,
      tvItemIndex: listIndex,
      child: PosterCard(
        imageUrl: imageUrlFor(movie),
        title: movie.title,
        subtitle: metaLine(movie),
        rating: movie.voteAverage > 0 ? movie.voteAverage : null,
        rank: rank,
        listPin: pin,
        width: w,
        height: h,
        borderRadius: radius,
        titleFontSize: shellHubCardTitleFontSize(context),
        metaFontSize: shellScaled(context, 11).clamp(7.0, 11.0),
        inset: inset,
      ),
    );
  }
}
