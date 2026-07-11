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

  static double cardHeight(BuildContext context) => shellMovieCardHeight(context);

  @override
  Widget build(BuildContext context) {
    final titleSize = shellHubCardTitleFontSize(context);
    final cardWidth = HomeMovieCard.cardWidth(context);
    final cardHeight = HomeMovieCard.cardHeight(context);
    final radius = shellCardBorderRadius(context);
    final inset = shellScaled(context, 10).clamp(4.0, 10.0);
    final metaSize = shellScaled(context, 11).clamp(7.0, 11.0);
    final compact = cardWidth < 85;
    final imageUrl = movie.posterPath.isNotEmpty
        ? TmdbApi.getImageUrl(movie.posterPath)
        : '';

    final card = shellFocusableTap(
      context: context,
      onTap: onTap,
      borderRadius: radius,
      listIndex: listIndex,
      onLeftEdge: onLeftEdge,
      onUpEdge: onUpEdge,
      tvTabId: tvTabId,
      tvRowId: tvRowId,
      tvItemIndex: listIndex,
      child: Container(
        width: cardWidth,
        height: cardHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: shellScaled(context, 16).clamp(4.0, 16.0),
              offset: Offset(0, shellScaled(context, 8).clamp(2.0, 8.0)),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
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
                              style: TextStyle(
                                fontSize: shellScaled(context, 10).clamp(7.0, 10.0),
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
                          style: TextStyle(
                            fontSize: shellScaled(context, 10).clamp(7.0, 10.0),
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
                  top: inset,
                  right: inset,
                  child: HomeMovieRatingBadge(voteAverage: movie.voteAverage),
                ),
              Positioned(
                bottom: inset,
                left: inset,
                right: inset,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      movie.title,
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: titleSize,
                        height: 1.15,
                      ),
                    ),
                    if (!compact &&
                        (movie.releaseDate.isNotEmpty ||
                            movie.mediaType == 'tv' ||
                            movie.mediaType == 'movie')) ...[
                      SizedBox(height: shellScaled(context, 4).clamp(1.0, 4.0)),
                      Text(
                        _metaLine(movie),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: metaSize,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!compact)
                Positioned(
                  top: inset,
                  left: inset,
                  child: MyListButton.movie(
                    movie: movie,
                    excludeFromTvTraversal: true,
                    iconSize: shellScaled(context, 18).clamp(12.0, 18.0),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (rank == null) return card;

    final rankSize = shellScaled(context, 120).clamp(48.0, 120.0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$rank',
          style: TextStyle(
            fontSize: rankSize,
            fontWeight: FontWeight.w900,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = shellScaled(context, 2).clamp(1.0, 2.0)
              ..color = Colors.white.withValues(alpha: 0.1),
            height: 0.85,
            letterSpacing: shellScaled(context, -8).clamp(-4.0, -2.0),
          ),
        ),
        card,
      ],
    );
  }

  static String _metaLine(Movie movie) {
    final parts = <String>[];
    if (movie.releaseDate.isNotEmpty) {
      parts.add(movie.releaseDate.split('-').first);
    }
    if (movie.mediaType == 'tv' || movie.mediaType == 'movie') {
      parts.add(movie.mediaType == 'tv' ? 'TV' : 'FILM');
    }
    return parts.join(' • ');
  }
}

class HomeMovieRatingBadge extends StatelessWidget {
  const HomeMovieRatingBadge({super.key, required this.voteAverage});

  final double voteAverage;

  @override
  Widget build(BuildContext context) {
    final padH = shellScaled(context, 7).clamp(3.0, 7.0);
    final padV = shellScaled(context, 4).clamp(2.0, 4.0);
    final fontSize = shellScaled(context, 11).clamp(7.0, 11.0);
    final iconSize = shellScaled(context, 12).clamp(8.0, 12.0);
    final radius = shellScaled(context, 8).clamp(4.0, 8.0);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: iconSize, color: Colors.amber),
          SizedBox(width: shellScaled(context, 3).clamp(1.0, 3.0)),
          Text(
            voteAverage.toStringAsFixed(1),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
