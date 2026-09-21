import 'package:flutter/material.dart';
import 'package:forja_foundation/components/crossfade_swap.dart';
import 'package:forja_foundation/components/network_image.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/utils/cover_urls.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

/// Poster tile aspect for [PosterCard].
enum PosterAspect { portrait, landscape }

/// Props-only catalog poster card (RFC-106 Zone A).
///
/// Host supplies sizes, focus chrome, and [listPin]. No ShellScope / Movie / TMDB.
class PosterCard extends StatelessWidget {
  const PosterCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.width,
    required this.height,
    this.subtitle,
    this.rating,
    this.rank,
    this.badge,
    this.listPin,
    this.onTap,
    this.aspect = PosterAspect.portrait,
    this.borderRadius = ShellTokens.posterCardRadius,
    this.titleFontSize = ShellTokens.posterTitleFontSizeMobile,
    this.metaFontSize = 11,
    this.inset = 10,
    this.backgroundColor = const Color(0xFF0A0A0A),
  });

  final String imageUrl;
  final String title;
  final String? subtitle;
  final double? rating;
  final int? rank;
  final String? badge;
  final Widget? listPin;
  final VoidCallback? onTap;
  final PosterAspect aspect;
  final double width;
  final double height;
  final double borderRadius;
  final double titleFontSize;
  final double metaFontSize;
  final double inset;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final compact = width < 85;
    final url = resolveAbsoluteCoverUrl(imageUrl);
    final card = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: backgroundColor,
              child: url.isNotEmpty
                  ? ForjaNetworkImage(
                      url: url,
                      fit: BoxFit.cover,
                      error: _titleFallback(compact),
                    )
                  : _titleFallback(compact),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Color(0xB3000000),
                    Color(0xF2000000),
                  ],
                  stops: [0.0, 0.45, 0.8, 1.0],
                ),
              ),
            ),
            if ((!compact && listPin != null) ||
                (rating != null && rating! > 0))
              Positioned(
                top: inset,
                left: inset,
                right: inset,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!compact && listPin != null) listPin!,
                    const Spacer(),
                    if (rating != null && rating! > 0)
                      RatingBadge(voteAverage: rating!),
                  ],
                ),
              ),
            if (badge != null && badge!.isNotEmpty)
              Positioned(
                top: inset,
                left: !compact && listPin != null ? inset + 26 : inset,
                child: CrossfadeSwap(
                  child: Container(
                    key: ValueKey(badge),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badge!.toUpperCase() == 'NOW'
                          ? const Color(0xFFEF4444)
                          : ForjaShellColors.iconMuted,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badge!,
                      style: TextStyle(
                        color: badge!.toUpperCase() == 'NOW'
                            ? Colors.white
                            : Colors.black,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
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
                  CrossfadeSwap(
                    child: Text(
                      title,
                      key: ValueKey(title),
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: titleFontSize,
                        height: 1.15,
                      ),
                    ),
                  ),
                  if (!compact &&
                      subtitle != null &&
                      subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    CrossfadeSwap(
                      child: Text(
                        subtitle!,
                        key: ValueKey(subtitle),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: metaFontSize,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final tappable = onTap == null
        ? card
        : GestureDetector(onTap: onTap, child: card);

    if (rank == null) return tappable;

    return PosterRankRow(rank: rank!, child: tappable);
  }

  Widget _titleFallback(bool compact) {
    return Center(
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: compact ? 7 : 10,
          color: Colors.white24,
        ),
      ),
    );
  }
}

/// Large outlined rank digit for Popular / top-N rails.
///
/// Keep outside focus/hover chrome so the border wraps the poster only.
class PosterRankMark extends StatelessWidget {
  const PosterRankMark({super.key, required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$rank',
      style: TextStyle(
        fontSize: ShellTokens.posterRankFontSize,
        fontWeight: FontWeight.w900,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ShellTokens.posterRankStrokeWidth
          ..color = Colors.white
              .withValues(alpha: ShellTokens.posterRankStrokeAlpha),
        height: ShellTokens.posterRankLineHeight,
        letterSpacing: ShellTokens.posterRankLetterSpacing,
      ),
    );
  }
}

/// Rank digit + poster; use when composing focus chrome around [child] only.
///
/// Wraps the row in [ShellPaintEnsureVisibleExtent] so TV focus scroll keeps
/// the digit on-screen (focus chrome is the poster alone).
class PosterRankRow extends StatelessWidget {
  const PosterRankRow({super.key, required this.rank, required this.child});

  final int rank;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShellPaintEnsureVisibleExtent(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          PosterRankMark(rank: rank),
          child,
        ],
      ),
    );
  }
}

/// Star + score chip for poster corners.
class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.voteAverage});

  final double voteAverage;

  @override
  Widget build(BuildContext context) {
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final fontSize = tv
        ? ShellTokens.posterRatingFontSizeTv
        : ShellTokens.posterRatingFontSize;
    final iconSize = tv
        ? ShellTokens.posterRatingIconSizeTv
        : ShellTokens.posterRatingIconSize;
    final padH =
        tv ? ShellTokens.posterRatingPadHTv : ShellTokens.posterRatingPadH;
    final padV =
        tv ? ShellTokens.posterRatingPadVTv : ShellTokens.posterRatingPadV;
    final radius =
        tv ? ShellTokens.posterRatingRadiusTv : ShellTokens.posterRatingRadius;
    final gap =
        tv ? ShellTokens.posterRatingGapTv : ShellTokens.posterRatingGap;
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
          SizedBox(width: gap),
          CrossfadeSwap(
            child: Text(
              voteAverage.toStringAsFixed(1),
              key: ValueKey(voteAverage.toStringAsFixed(1)),
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Text-only rating chip (Stremio / opaque score strings).
class RatingBadgeText extends StatelessWidget {
  const RatingBadgeText({super.key, required this.rating});

  final String rating;

  @override
  Widget build(BuildContext context) {
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final fontSize = tv
        ? ShellTokens.posterRatingFontSizeTv
        : ShellTokens.posterRatingFontSize;
    final iconSize = tv
        ? ShellTokens.posterRatingIconSizeTv
        : ShellTokens.posterRatingIconSize;
    final padH =
        tv ? ShellTokens.posterRatingPadHTv : ShellTokens.posterRatingPadH;
    final padV =
        tv ? ShellTokens.posterRatingPadVTv : ShellTokens.posterRatingPadV;
    final radius =
        tv ? ShellTokens.posterRatingRadiusTv : ShellTokens.posterRatingRadius;
    final gap =
        tv ? ShellTokens.posterRatingGapTv : ShellTokens.posterRatingGap;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, color: Colors.amber, size: iconSize),
          SizedBox(width: gap),
          CrossfadeSwap(
            child: Text(
              rating,
              key: ValueKey(rating),
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
