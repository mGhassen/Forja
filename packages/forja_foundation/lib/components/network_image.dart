import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_theme_extension.dart';

/// Network image for catalog cards — absolute http(s) URLs only.
///
/// Named [ForjaNetworkImage] to avoid clashing with Flutter's [NetworkImage]
/// image provider.
///
/// Does **not** swap in a skeleton/placeholder while decoding — that reads as
/// rail "reload" when ImageCache misses after another hub filled the cache.
/// Dark fill sits under the image; [gaplessPlayback] keeps the prior frame on
/// URL updates when [useOldImageOnUrlChange] is true.
class ForjaNetworkImage extends StatelessWidget {
  const ForjaNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.borderRadius,
    this.fadeDuration = Duration.zero,
    this.placeholder,
    this.error,
    this.useOldImageOnUrlChange = true,
    this.memCacheWidth,
    this.filterQuality = FilterQuality.medium,
  });

  final String url;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Duration fadeDuration;
  final Widget? placeholder;
  final Widget? error;
  final bool useOldImageOnUrlChange;
  final int? memCacheWidth;
  final FilterQuality filterQuality;

  bool get _isAbsolute {
    final u = url.trim();
    return u.startsWith('http://') || u.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final radius = borderRadius ?? BorderRadius.zero;
    final fill = placeholder ?? ColoredBox(color: theme.surfaceElevated);
    final fallback = error ?? fill;

    if (!_isAbsolute) {
      return SizedBox(
        width: width,
        height: height,
        child: ClipRRect(borderRadius: radius, child: fallback),
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            fill,
            Image.network(
              url.trim(),
              key: useOldImageOnUrlChange ? null : ValueKey(url.trim()),
              fit: fit,
              alignment: alignment,
              width: width,
              height: height,
              cacheWidth: memCacheWidth,
              filterQuality: filterQuality,
              gaplessPlayback: true,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded ||
                    frame != null ||
                    fadeDuration == Duration.zero) {
                  return child;
                }
                return AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: fadeDuration,
                  child: child,
                );
              },
              errorBuilder: (_, _, _) => fallback,
            ),
          ],
        ),
      ),
    );
  }
}
