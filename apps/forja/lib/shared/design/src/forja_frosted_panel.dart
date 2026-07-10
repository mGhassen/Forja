import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'forja_shell_colors.dart';

/// Frosted sliding side-panel shell (Sources, Episodes, torrent files).
///
/// - Details / non-video: [enableBlur] → [BackdropFilter]
/// - Player over live video: pass [frozenFrame] → [ImageFiltered] on that still
///   (BackdropFilter over a Texture layer freezes the UI on macOS)
class ForjaFrostedPanel extends StatelessWidget {
  const ForjaFrostedPanel({
    super.key,
    required this.child,
    this.border,
    this.borderRadius,
    this.elevation = 0,
    this.enableBlur = true,
    this.frozenFrame,
  });

  static const double blurSigma = 22;

  /// [menuSurface] at ~72% so frosted glass reads clearly.
  static Color get tint =>
      ForjaShellColors.cinematic.menuSurface.withValues(alpha: 0.72);

  final Widget child;
  final BoxBorder? border;
  final BorderRadius? borderRadius;
  final double elevation;
  final bool enableBlur;

  /// JPEG/PNG still (e.g. player screenshot). Prefer over BackdropFilter on video.
  final Uint8List? frozenFrame;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.zero;
    final useFrozen = frozenFrame != null && frozenFrame!.isNotEmpty;
    final useBackdrop = enableBlur && !useFrozen;

    final tintedChild = Material(
      color: Colors.transparent,
      elevation: elevation,
      shadowColor: Colors.black.withValues(alpha: 0.5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: (useBackdrop || useFrozen)
              ? tint
              : ForjaShellColors.cinematic.menuSurface,
          borderRadius: radius,
          border: border,
        ),
        child: child,
      ),
    );

    if (useFrozen) {
      return ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: blurSigma,
                  sigmaY: blurSigma,
                  tileMode: TileMode.clamp,
                ),
                child: Image.memory(
                  frozenFrame!,
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.low,
                ),
              ),
            ),
            tintedChild,
          ],
        ),
      );
    }

    if (!useBackdrop) {
      return ClipRRect(
        borderRadius: radius,
        child: tintedChild,
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: tintedChild,
      ),
    );
  }
}
