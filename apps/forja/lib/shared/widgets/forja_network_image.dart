import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Resilient remote image — load failures stay in [error], not FlutterError.
class ForjaNetworkImage extends StatelessWidget {
  const ForjaNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.memCacheWidth,
    this.filterQuality = FilterQuality.medium,
    this.placeholder,
    this.error,
    this.useOldImageOnUrlChange = true,
  });

  final String url;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;
  final int? memCacheWidth;
  final FilterQuality filterQuality;
  final Widget? placeholder;
  final Widget? error;
  final bool useOldImageOnUrlChange;

  @override
  Widget build(BuildContext context) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return error ?? const SizedBox.shrink();
    }

    final fallback = error ?? const SizedBox.shrink();
    return CachedNetworkImage(
      imageUrl: trimmed,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      memCacheWidth: memCacheWidth,
      filterQuality: filterQuality,
      useOldImageOnUrlChange: useOldImageOnUrlChange,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (context, url) => placeholder ?? fallback,
      errorWidget: (context, url, error) => fallback,
    );
  }
}
