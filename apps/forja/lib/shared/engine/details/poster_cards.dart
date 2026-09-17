import 'package:flutter/material.dart';
import 'package:forja/shared/engine/runtime/kit/hosts/kit_list_status_button.dart';
import 'package:forja/shell/focus/shell_focusable_tap.dart';
import 'package:forja_foundation/utils/cover_urls.dart';
import 'package:forja_foundation/widgets/catalog/interactive_poster_card.dart';
import 'package:rust/rust.dart';

export 'package:forja_foundation/widgets/catalog/interactive_poster_card.dart'
    show PosterAspect, InteractivePosterCard;
export 'package:forja_foundation/widgets/catalog/poster_card.dart'
    show PosterCard, RatingBadge;

typedef MovieRatingBadge = RatingBadge;

/// TMDB/movie poster — props from [Movie] protocol fields only.
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

  static double cardWidth(BuildContext context) =>
      InteractivePosterCard.cardWidth(context);

  static double cardHeight(BuildContext context) =>
      InteractivePosterCard.cardHeight(context);

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
    final w = cardWidth(context);
    final h = cardHeight(context);
    const radius = 14.0;
    final compact = w < 85;
    final pin = !compact
        ? KitListStatusButton.movie(
            movie: movie,
            excludeFromTvTraversal: true,
            iconSize: 18,
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
        titleFontSize: 12,
        metaFontSize: 11,
        inset: 10,
      ),
    );
  }
}

enum KitPosterAspect { portrait, landscape }

/// Poster paint from caller-supplied props (pack/protocol already shaped).
class KitPosterCard extends StatelessWidget {
  const KitPosterCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.onTap,
    this.onLongPress,
    this.subtitle,
    this.rating,
    this.rank,
    this.badge,
    this.listPin,
    this.listIndex,
    this.onUpEdge,
    this.onLeftEdge,
    this.onRightEdge,
    this.aspect = KitPosterAspect.portrait,
  });

  final String imageUrl;
  final String title;
  final String? subtitle;
  final double? rating;
  final int? rank;
  final String? badge;
  final Widget? listPin;
  final int? listIndex;
  final VoidCallback? onUpEdge;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final KitPosterAspect aspect;

  static double cardWidth(
    BuildContext context, {
    KitPosterAspect aspect = KitPosterAspect.portrait,
  }) =>
      InteractivePosterCard.cardWidth(
        context,
        aspect: aspect == KitPosterAspect.landscape
            ? PosterAspect.landscape
            : PosterAspect.portrait,
      );

  static double cardHeight(
    BuildContext context, {
    KitPosterAspect aspect = KitPosterAspect.portrait,
  }) =>
      InteractivePosterCard.cardHeight(
        context,
        aspect: aspect == KitPosterAspect.landscape
            ? PosterAspect.landscape
            : PosterAspect.portrait,
      );

  @override
  Widget build(BuildContext context) {
    return InteractivePosterCard(
      imageUrl: imageUrl,
      title: title,
      subtitle: subtitle,
      rating: rating,
      rank: rank,
      badge: badge,
      listPin: listPin,
      listIndex: listIndex,
      onUpEdge: onUpEdge,
      onLeftEdge: onLeftEdge,
      onRightEdge: onRightEdge,
      onTap: onTap,
      onLongPress: onLongPress,
      aspect: aspect == KitPosterAspect.landscape
          ? PosterAspect.landscape
          : PosterAspect.portrait,
    );
  }
}
