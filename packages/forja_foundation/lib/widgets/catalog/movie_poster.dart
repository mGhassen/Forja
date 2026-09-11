import 'package:flutter/material.dart';
import 'package:forja_foundation/components/network_image.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/utils/cover_urls.dart';
import 'package:forja_foundation/widgets/catalog/poster_card.dart';

/// Simple hover poster — absolute [imageUrl] only (no TMDB client).
class MoviePoster extends StatefulWidget {
  const MoviePoster({
    super.key,
    required this.imageUrl,
    required this.title,
    this.rating,
    this.onTap,
    this.listPin,
    this.borderRadius = 16,
  });

  final String imageUrl;
  final String title;
  final double? rating;
  final VoidCallback? onTap;
  final Widget? listPin;
  final double borderRadius;

  @override
  State<MoviePoster> createState() => _MoviePosterState();
}

class _MoviePosterState extends State<MoviePoster> {
  bool _hovered = false;
  bool _focused = false;

  bool get _active => _hovered || _focused;

  @override
  Widget build(BuildContext context) {
    final url = resolveAbsoluteCoverUrl(widget.imageUrl);
    return InkWell(
      onFocusChange: (f) => setState(() => _focused = f),
      onHover: (h) => setState(() => _hovered = h),
      onTap: widget.onTap,
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      splashColor: ForjaShellColors.brandGreen.withValues(alpha: 0.3),
      highlightColor: Colors.transparent,
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: AnimatedScale(
        scale: _active ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: _active
                  ? ForjaShellColors.chipSelectedBorder
                  : Colors.white10,
              width: _active ? 3 : 1,
            ),
            boxShadow: _active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 15,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : const [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius - 3),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ForjaNetworkImage(
                  url: url,
                  fit: BoxFit.cover,
                  memCacheWidth: 340,
                  error: const Icon(Icons.error),
                ),
                AnimatedOpacity(
                  opacity: _active ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          const Color(0xFF141414).withValues(alpha: 0.8),
                          const Color(0xFF141414),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        if (widget.rating != null && widget.rating! > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.star,
                                  color: Colors.amber, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                widget.rating!.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (widget.listPin != null)
                  Positioned(top: 6, left: 6, child: widget.listPin!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Alias for TMDB-style poster tiles that already have an absolute image URL.
typedef MoviePosterCard = PosterCard;
