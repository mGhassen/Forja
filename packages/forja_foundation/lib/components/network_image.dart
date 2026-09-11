import 'package:flutter/material.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';

/// Fading network image — absolute http(s) URLs only.
///
/// Named [ForjaNetworkImage] to avoid clashing with Flutter's [NetworkImage]
/// image provider.
class ForjaNetworkImage extends StatelessWidget {
  const ForjaNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.borderRadius,
    this.fadeDuration = const Duration(milliseconds: 250),
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
    final fallback = error ??
        placeholder ??
        ColoredBox(color: theme.surfaceElevated);

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
        child: Image.network(
          url.trim(),
          key: useOldImageOnUrlChange ? null : ValueKey(url.trim()),
          fit: fit,
          alignment: alignment,
          width: width,
          height: height,
          cacheWidth: memCacheWidth,
          filterQuality: filterQuality,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) {
              return AnimatedOpacity(
                opacity: 1,
                duration: fadeDuration,
                child: child,
              );
            }
            return placeholder ??
                ColoredBox(color: Colors.white.withValues(alpha: 0.04));
          },
          errorBuilder: (_, _, _) => fallback,
        ),
      ),
    );
  }
}
