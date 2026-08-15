import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Network image that keeps the last frame until the next URL has decoded.
///
/// TMDB enrich swaps KissKH / AniList / IPTV art for a new CDN URL. Default
/// [CachedNetworkImage] clears the old frame first — a blank hero/thumb.
class SettledNetworkImage extends StatelessWidget {
  const SettledNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.low,
    this.errorWidget,
  });

  final String imageUrl;
  final BoxFit fit;
  final Alignment alignment;
  final FilterQuality filterQuality;
  final Widget? errorWidget;

  static const _empty = ColoredBox(color: Color(0xFF141414));

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) return errorWidget ?? _empty;
    return Image(
      image: CachedNetworkImageProvider(imageUrl),
      fit: fit,
      alignment: alignment,
      filterQuality: filterQuality,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => errorWidget ?? _empty,
    );
  }
}
