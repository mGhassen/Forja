import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_theme_extension.dart';
import 'package:forja_foundation/utils/cover_urls.dart';

/// Network image for catalog cards — absolute http(s) URLs only.
///
/// Named [ForjaNetworkImage] to avoid clashing with Flutter's [NetworkImage]
/// image provider.
///
/// Outer [Stack] + [StackFit.expand] keeps the paint box fixed to the parent
/// (channel logo slot, poster cell). When [paintUnderlay] is true (default), a
/// solid surface sits under the decoded frame so transparent PNGs do not show
/// chrome through empty pixels. Channel cards set [paintUnderlay] false so the
/// card face shows through — no nested elevated square on focus/hover. Custom
/// [placeholder] widgets (icons, skeletons) show only while loading — removed
/// once the first frame arrives so they cannot stack under a loaded logo.
/// [gaplessPlayback] keeps the prior frame on URL updates when
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
    this.paintUnderlay = true,
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

  /// Solid [ForjaThemeExtension.surfaceElevated] under the image. Turn off for
  /// channel logos so transparent PNGs sit on the card face (no inset square).
  final bool paintUnderlay;

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
    final paintUrl = paintableNetworkImageUrl(url);

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
        // Expand + Positioned.fill so paint always matches the parent slot
        // (channel logo box, poster cell). Never size to PNG intrinsic pixels.
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (paintUnderlay) surface,
            Positioned.fill(
              child: Image.network(
                paintUrl,
                key: useOldImageOnUrlChange ? null : ValueKey(paintUrl),
                fit: fit,
                alignment: alignment,
                cacheWidth: memCacheWidth,
                filterQuality: filterQuality,
                gaplessPlayback: true,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  final loaded = wasSynchronouslyLoaded || frame != null;
                  Widget image = child;
                  if (!wasSynchronouslyLoaded &&
                      fadeDuration != Duration.zero) {
                    image = AnimatedOpacity(
                      opacity: loaded ? 1 : 0,
                      duration: fadeDuration,
                      curve: Curves.easeOut,
                      child: child,
                    );
                  }
                  if (loaded) return image;
                  // Icon/skeleton only while waiting — never under a loaded logo.
                  return Stack(
                    fit: StackFit.expand,
                    children: [loading, image],
                  );
                },
                errorBuilder: (_, _, _) => fallback,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
