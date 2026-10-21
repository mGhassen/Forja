import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/top_bar_scrim_tokens.dart';

/// Vertical gradient (menu surface → transparent) painted behind an overlay
/// top bar so its labels never collide with content scrolling underneath.
///
/// Flat cinematic shell: a plain gradient, never `BackdropFilter`. [opacity]
/// is folded into the gradient colors (no save-layer per frame).
class TopBarScrim extends StatelessWidget {
  const TopBarScrim({super.key, required this.height, this.opacity = 1});

  final double height;

  /// 0 → nothing painted; 1 → full token alphas.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final o = opacity.clamp(0.0, 1.0);
    if (o <= 0 || height <= 0) return const SizedBox.shrink();
    final surface = ForjaShellColors.cinematic.menuSurface;
    return IgnorePointer(
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                surface.withValues(alpha: TopBarScrimTokens.topAlpha * o),
                surface.withValues(alpha: TopBarScrimTokens.midAlpha * o),
                surface.withValues(alpha: 0),
              ],
              stops: const [0, TopBarScrimTokens.midStop, 1],
            ),
          ),
        ),
      ),
    );
  }
}
