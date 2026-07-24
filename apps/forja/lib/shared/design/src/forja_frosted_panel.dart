import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'forja_shell_colors.dart';

/// Frosted sliding side-panel shell (Sources, Episodes, Filters).
///
/// Details ([enableBlur] true, no [frozenFrame]): [BackdropFilter] over the page.
///
/// Player: pass [frozenFrame] and set [enableBlur] false. Blurs the still with
/// [ImageFiltered] (not [BackdropFilter]) so Overlay panels never sample the
/// live video Texture (macOS freeze) and the frost is always visible.
class ForjaFrostedPanel extends StatelessWidget {
  const ForjaFrostedPanel({
    super.key,
    required this.child,
    this.border,
    this.borderRadius,
    this.elevation = 0,
    this.enableBlur = true,
    this.frozenFrame,
    this.blurSigma = defaultBlurSigma,
  });

  /// Default for Sources / Episodes panels.
  static const double defaultBlurSigma = 48;

  /// Light glass — blur must read through; keep alpha low.
  static Color get tint =>
      ForjaShellColors.cinematic.menuSurface.withValues(alpha: 0.28);

  final Widget child;
  final BoxBorder? border;
  final BorderRadius? borderRadius;
  final double elevation;
  final bool enableBlur;
  final Uint8List? frozenFrame;

  /// Backdrop / frozen-frame blur strength.
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.zero;
    final hasFrame = frozenFrame != null && frozenFrame!.isNotEmpty;
    final sigma = blurSigma;

    // Player / Overlay path — blur the still locally (ImageFiltered).
    if (hasFrame) {
      return ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: sigma,
                  sigmaY: sigma,
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
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                elevation: elevation,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: radius,
                    border: border,
                  ),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Player without a frame — translucent dark, not opaque #141414.
    if (!enableBlur) {
      return ClipRRect(
        borderRadius: radius,
        child: Material(
          color: Colors.transparent,
          elevation: elevation,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: ForjaShellColors.cinematic.menuSurface
                  .withValues(alpha: 0.82),
              borderRadius: radius,
              border: border,
            ),
            child: child,
          ),
        ),
      );
    }

    // Details page — blur whatever is behind the panel.
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: Material(
          color: Colors.transparent,
          elevation: elevation,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tint,
              borderRadius: radius,
              border: border,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
