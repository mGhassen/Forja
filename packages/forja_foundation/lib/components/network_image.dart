import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_theme_extension.dart';

/// Network image for catalog cards — absolute http(s) URLs only.
///
/// Named [ForjaNetworkImage] to avoid clashing with Flutter's [NetworkImage]
/// image provider.
///
/// A solid surface sits under the decoded frame so transparent PNGs (channel
/// logos, title art) do not show chrome through empty pixels. Custom
/// [placeholder] widgets (icons, skeletons) show only while loading — they
/// are removed once the first frame arrives so they cannot stack under a
/// loaded logo. [gaplessPlayback] keeps the prior frame on URL updates when
/// [useOldImageOnUrlChange] is true. First frame fades in ([fadeDuration]).
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
    final surface = ColoredBox(color: theme.surfaceElevated);
    final loading = placeholder ?? surface;
    final fallback = error ?? loading;

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
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            final loaded = wasSynchronouslyLoaded || frame != null;
            Widget image = child;
            if (!wasSynchronouslyLoaded && fadeDuration != Duration.zero) {
              image = AnimatedOpacity(
                opacity: loaded ? 1 : 0,
                duration: fadeDuration,
                curve: Curves.easeOut,
                child: child,
              );
            }
            return Stack(
              fit: StackFit.expand,
              children: [
                // Opaque underlay for transparent logos / PNGs.
                surface,
                // Icon/skeleton placeholders — only while waiting for a frame.
                if (!loaded) loading,
                image,
              ],
            );
          },
          errorBuilder: (_, _, _) => fallback,
        ),
      ),
    );
  }
}
