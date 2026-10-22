import 'dart:math' as math;

import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/tokens/top_bar_scrim_tokens.dart';

/// How far the hub top menu has slid away (0 painted … 1 hidden).
///
/// [heroHeight] is the bottom of the hero text column (foundation
/// `CinematicHeroState.chromeFadeHeight` — title → CTA row). The slide runs
/// over [slideDistance] and completes exactly when that edge reaches the
/// bar's bottom, so at every step the (partially lifted) bar still ends above
/// the hero chrome: bar bottom = barHeight·(1−p) ≤ chrome edge =
/// barHeight + slideDistance·(1−p). A hub without a hero (0) never hides —
/// the scrim keeps its labels legible instead.
double kitTopBarHideProgress({
  required double scrollOffset,
  required double heroHeight,
  required double barHeight,
  double slideDistance = ShellTokens.kitTopBarHideSlideDistance,
}) {
  if (heroHeight <= 0 || slideDistance <= 0) return 0;
  final hideStart = math.max(0.0, heroHeight - barHeight - slideDistance);
  return ((scrollOffset - hideStart) / slideDistance).clamp(0.0, 1.0);
}

/// Opacity of the gradient scrim behind the menu: none at rest (hero text
/// already clears the bar), fades in over [fadeInDistance] of scroll, and
/// fades out with the bar as [hideProgress] → 1.
double kitTopBarScrimOpacity({
  required double scrollOffset,
  required double hideProgress,
  double fadeInDistance = TopBarScrimTokens.scrollFadeInDistance,
}) {
  if (hideProgress >= 1) return 0;
  final fadeIn = fadeInDistance <= 0
      ? 1.0
      : (scrollOffset / fadeInDistance).clamp(0.0, 1.0);
  return fadeIn * (1 - hideProgress.clamp(0.0, 1.0));
}
