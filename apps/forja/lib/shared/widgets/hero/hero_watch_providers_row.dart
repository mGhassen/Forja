import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:rust/rust.dart';

/// TMDB watch-provider logos for media details hero (Netflix, Disney+, etc.).
class HeroWatchProvidersRow extends StatelessWidget {
  const HeroWatchProvidersRow({
    super.key,
    required this.providers,
    this.maxVisible = 8,
  });

  final List<WatchProvider> providers;
  final int maxVisible;

  static const double tileSize = 40;
  static const double tileGap = 8;
  static const double rowHeight = tileSize;

  @override
  Widget build(BuildContext context) {
    final visible = providers
        .where((p) => p.logoPath.isNotEmpty)
        .take(maxVisible)
        .toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: rowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        itemCount: visible.length,
        separatorBuilder: (_, _) => const SizedBox(width: tileGap),
        itemBuilder: (context, index) {
          final provider = visible[index];
          return Tooltip(
            message: provider.name,
            child: Semantics(
              label: provider.name,
              child: SizedBox(
                width: tileSize,
                height: tileSize,
                child: CachedNetworkImage(
                  imageUrl: provider.logoUrl,
                  fit: BoxFit.contain,
                  errorWidget: (_, _, _) => Text(
                    provider.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
