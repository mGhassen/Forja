import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/home_movie_card.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';

/// Poster frame for hub catalog rows.
///
/// [HubPosterAspect.portrait] — TMDB / AniList 2:3 posters (Home, Anime).
/// [HubPosterAspect.landscape] — 16:9 banners (KissKH list thumbs).
enum HubPosterAspect { portrait, landscape }

class HubPosterCard extends StatelessWidget {
  const HubPosterCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.rating,
    this.rank,
    this.badge,
    this.listIndex,
    this.tvTabId,
    this.tvRowId,
    this.onUpEdge,
    this.aspect = HubPosterAspect.portrait,
  });

  final String imageUrl;
  final String title;
  final String? subtitle;
  final double? rating;
  final int? rank;
  final String? badge;
  final int? listIndex;
  final String? tvTabId;
  final String? tvRowId;
  final VoidCallback? onUpEdge;
  final VoidCallback onTap;
  final HubPosterAspect aspect;

  static double cardWidth(
    BuildContext context, {
    HubPosterAspect aspect = HubPosterAspect.portrait,
  }) {
    if (aspect == HubPosterAspect.landscape) {
      return shellContinueWatchingCardWidth(context);
    }
    return HomeMovieCard.cardWidth(context);
  }

  static double cardHeight(
    BuildContext context, {
    HubPosterAspect aspect = HubPosterAspect.portrait,
  }) {
    if (aspect == HubPosterAspect.landscape) {
      return shellContinueWatchingCardHeight(context);
    }
    return HomeMovieCard.cardHeight(context);
  }

  @override
  Widget build(BuildContext context) {
    final titleSize = shellHubCardTitleFontSize(context);
    final cardWidth = HubPosterCard.cardWidth(context, aspect: aspect);
    final cardHeight = HubPosterCard.cardHeight(context, aspect: aspect);
    final radius = shellCardBorderRadius(context);
    final inset = shellScaled(context, 10).clamp(4.0, 10.0);
    final metaSize = shellScaled(context, 11).clamp(7.0, 11.0);
    final compact = cardWidth < 85;

    final card = shellFocusableTap(
      context: context,
      onTap: onTap,
      borderRadius: radius,
      showFocusBorder: true,
      listIndex: listIndex,
      tvTabId: tvTabId,
      tvRowId: tvRowId,
      tvItemIndex: listIndex,
      onUpEdge: onUpEdge,
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
                              title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: shellScaled(
                                  context,
                                  10,
                                ).clamp(7.0, 10.0),
                                color: Colors.white24,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          title,
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
              if (rating != null && rating! > 0)
                Positioned(
                  top: inset,
                  right: inset,
                  child: HomeMovieRatingBadge(voteAverage: rating!),
                ),
              if (badge != null && badge!.isNotEmpty)
                Positioned(
                  top: inset,
                  left: inset,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: shellScaled(context, 6).clamp(3.0, 6.0),
                      vertical: shellScaled(context, 2).clamp(1.0, 2.0),
                    ),
                    decoration: BoxDecoration(
                      color: ForjaShellColors.iconMuted,
                      borderRadius: BorderRadius.circular(
                        shellScaled(context, 4).clamp(2.0, 4.0),
                      ),
                    ),
                    child: Text(
                      badge!,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: shellScaled(context, 9).clamp(7.0, 9.0),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
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
                      title,
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
                        subtitle != null &&
                        subtitle!.isNotEmpty) ...[
                      SizedBox(height: shellScaled(context, 4).clamp(1.0, 4.0)),
                      Text(
                        subtitle!,
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
}
