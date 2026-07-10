import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/my_list_button.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:rust/rust.dart';

class HomeMovieCard extends StatelessWidget {
  const HomeMovieCard({
    super.key,
    required this.movie,
    required this.onTap,
    this.rank,
    this.listIndex,
    this.onLeftEdge,
    this.onUpEdge,
  });

  final Movie movie;
  final VoidCallback onTap;
  final int? rank;
  final int? listIndex;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onUpEdge;

  static double cardWidth(BuildContext context) => shellMovieCardWidth(context);

  static double cardHeight(BuildContext context) => shellMovieCardHeight(context);

  @override
  Widget build(BuildContext context) {
    final titleSize = shellHubCardTitleFontSize(context);
    final cardWidth = HomeMovieCard.cardWidth(context);
    final cardHeight = HomeMovieCard.cardHeight(context);
    final imageUrl = movie.posterPath.isNotEmpty
        ? TmdbApi.getImageUrl(movie.posterPath)
        : '';

    final card = shellFocusableTap(
      context: context,
      onTap: onTap,
      borderRadius: 14,
      listIndex: listIndex,
      onLeftEdge: onLeftEdge,
      onUpEdge: onUpEdge,
      child: Container(
        width: cardWidth,
        height: cardHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: AppTheme.bgDark,
                child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                        placeholder: (c, u) =>
                            ColoredBox(color: AppTheme.bgDark),
                        errorWidget: (c, u, e) => Container(
                          color: AppTheme.bgDark,
                          child: Center(
                            child: Text(
                              movie.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white24,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          movie.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white24,
                          ),
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
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                      Colors.black.withValues(alpha: 0.95),
                    ],
                    stops: const [0.0, 0.45, 0.8, 1.0],
                  ),
                ),
              ),
              if (movie.voteAverage > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: HomeMovieRatingBadge(voteAverage: movie.voteAverage),
                ),
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      movie.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: titleSize,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (movie.releaseDate.isNotEmpty)
                          Text(
                            movie.releaseDate.split('-').first,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 11,
                            ),
                          ),
                        if (movie.mediaType == 'tv' ||
                            movie.mediaType == 'movie') ...[
                          if (movie.releaseDate.isNotEmpty) ...[
                            Text(
                              '  •  ',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.3),
                                fontSize: 11,
                              ),
                            ),
                          ],
                          Text(
                            movie.mediaType == 'tv' ? 'TV' : 'FILM',
                            style: TextStyle(
                              color: ForjaShellColors.badgeLabel,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: MyListButton.movie(
                  movie: movie,
                  excludeFromTvTraversal: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (rank == null) return card;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$rank',
          style: TextStyle(
            fontSize: 120,
            fontWeight: FontWeight.w900,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = Colors.white.withValues(alpha: 0.1),
            height: 0.85,
            letterSpacing: -8,
          ),
        ),
        card,
      ],
    );
  }
}

class HomeMovieRatingBadge extends StatelessWidget {
  const HomeMovieRatingBadge({super.key, required this.voteAverage});

  final double voteAverage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
          const SizedBox(width: 3),
          Text(
            voteAverage.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
