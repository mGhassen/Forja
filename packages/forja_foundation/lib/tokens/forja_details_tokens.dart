import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Layout constants for media-details surfaces (hero, body, sources panel).
///
/// Details are a **section stack**: hero chrome (optional) then zero or more
/// body sections. Packs may omit hero, episodes, or any rail — host only
/// applies spacing rules, never row-type layout branches.
///
/// Backdrop height + first-row Y are **pack `layout` props** (see
/// [parseKitDetailsLayout]). Tokens here are defaults / math only.
///
/// Content gutters reuse [ShellTokens] so details stay aligned with shell
/// catalog rows and body max-width.
abstract final class DetailsTokens {
  /// Extra pull-up for movie details body (cast/trailers) when the host opts in.
  static const double heroBodyOverlap = 120;

  static const double heroContentTopInset = 88;
  static const double heroDescriptionWidthFraction = 0.40;

  /// Gap after the hero before the first section, and between every section.
  static const double sectionSpacing = 48;

  /// Alias — first section under hero uses the same rhythm as between sections.
  static const double bodyTopSpacing = sectionSpacing;

  /// Title → row gap inside cast / trailers / recommendations on details.
  static const double sectionTitleGap = 16;
  static const double bodyBottomSpacing = 80;

  /// Sources sliding panel on media details (player overlays use
  /// [ShellTokens.playerSidePanelPadding]).
  static const EdgeInsets sourcesPanelPadding = EdgeInsets.fromLTRB(
    16,
    8,
    12,
    12,
  );

  static const double contentPaddingDesktop =
      ShellTokens.homeSectionHorizontalPadding;
  static const double contentPaddingCompact =
      ShellTokens.homeSectionHorizontalPadding;

  static double contentHorizontalPadding(double viewportWidth) {
    if (viewportWidth >= ShellTokens.shellNavCompactMaxWidth) {
      return contentPaddingDesktop;
    }
    return contentPaddingCompact;
  }

  /// Left edge of the centered details content column for [viewportWidth].
  /// Pass the overlay/stack width (rail already subtracted), not full-window
  /// [MediaQuery] size — otherwise the nav rail is double-counted.
  static double contentLeftInset(double viewportWidth) {
    final padding = contentHorizontalPadding(viewportWidth);
    final columnWidth = viewportWidth < ShellTokens.bodyMaxWidthDesktop
        ? viewportWidth
        : ShellTokens.bodyMaxWidthDesktop;
    final sideGutter = (viewportWidth - columnWidth) / 2;
    return sideGutter + padding;
  }

  /// Default hero band when pack omits `layout.backdropFraction` / full-bleed.
  static const double heroViewportFraction = 0.82;

  /// Default first-row Y when pack opts into overlap without a fraction.
  static const double firstBodyRowViewportFraction = 0.65;

  /// Hero chrome height from pack layout + viewport.
  static double heroHeight(
    BuildContext context, {
    double? viewportHeight,
    bool fullBleedBackdrop = false,
    double? backdropFraction,
  }) {
    final size = MediaQuery.sizeOf(context);
    final height = viewportHeight ?? size.height;
    final resolved = height.isFinite && height > 0 ? height : size.height;
    if (fullBleedBackdrop) return resolved;
    final fraction = (backdropFraction ?? heroViewportFraction).clamp(0.2, 1.0);
    return resolved * fraction;
  }

  /// Pull-up so the first body row sits at [firstBodyRowFraction] of the
  /// viewport while overlapping a hero of [heroHeight].
  static double bodyOverlapForFirstRow({
    required double viewportHeight,
    required double heroHeight,
    double? firstBodyRowFraction,
  }) {
    final f = firstBodyRowFraction;
    if (f == null || !f.isFinite || f <= 0 || f >= 1) return 0;
    final vh =
        viewportHeight.isFinite && viewportHeight > 0 ? viewportHeight : 0.0;
    if (vh <= 0 || heroHeight <= 0) return 0;
    final firstRowY = vh * f;
    final overlap = heroHeight - firstRowY;
    if (overlap <= 0) return 0;
    return overlap.clamp(0.0, heroHeight);
  }
}
