import 'package:flutter/material.dart';
import 'package:forja_foundation/components/network_image.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/utils/cover_urls.dart';

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
    this.borderRadius = 14,
    this.titleFontSize = 13,
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
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: ForjaShellColors.iconMuted,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 9,
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
                      fontSize: titleFontSize,
                      height: 1.15,
                    ),
                  ),
                  if (!compact &&
                      subtitle != null &&
                      subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: metaFontSize,
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
        tappable,
      ],
    );
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

/// Star + score chip for poster corners.
class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.voteAverage});

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

/// Text-only rating chip (Stremio / opaque score strings).
class RatingBadgeText extends StatelessWidget {
  const RatingBadgeText({super.key, required this.rating});

  final String rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Colors.amber, size: 11),
          const SizedBox(width: 2),
          Text(
            rating,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
