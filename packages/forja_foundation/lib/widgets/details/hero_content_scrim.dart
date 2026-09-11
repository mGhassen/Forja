import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Soft dark scrim for live match hero — title through streams, edge to edge.
class KitHeroContentScrim extends StatelessWidget {
  const KitHeroContentScrim({
    super.key,
    this.tintAlpha = 0.66,
    this.blurSigma = 24,
  });

  final double tintAlpha;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final tint = ForjaShellColors.cinematic.menuSurface.withValues(
      alpha: tintAlpha,
    );
    return IgnorePointer(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x00FFFFFF),
            Color(0xFFFFFFFF),
            Color(0xFFFFFFFF),
            Color(0x00FFFFFF),
          ],
          stops: [0.0, 0.28, 0.82, 1.0],
        ).createShader(bounds),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: ColoredBox(color: tint),
        ),
      ),
    );
  }
}
