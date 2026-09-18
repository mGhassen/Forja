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
  static const double heroBodyOverlapTv = 72;

  static const double heroContentTopInset = 88;
  static const double heroContentTopInsetTv = 48;
  static const double heroDescriptionWidthFraction = 0.40;

  /// Gap after the hero before the first section, and between every section.
  static const double sectionSpacing = 48;
  static const double sectionSpacingTv = 24;

  /// Alias — first section under hero uses the same rhythm as between sections.
  static const double bodyTopSpacing = sectionSpacing;
  static const double bodyTopSpacingTv = sectionSpacingTv;

  /// Title → row gap inside cast / trailers / recommendations on details.
  static const double sectionTitleGap = 16;
  static const double sectionTitleGapTv = 10;
  static const double bodyBottomSpacing = 80;
  static const double bodyBottomSpacingTv = 48;

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

  static const double castAvatarSize = 88;
  static const double castAvatarSizeTv = 56;
  static const double castItemWidth = 112;
  static const double castItemWidthTv = 72;
  static const double castGap = 32;
  static const double castGapTv = 16;
  static const double trailerCardWidth = 200;
  static const double trailerCardWidthTv = 140;
  static const double episodeSeasonWidth = 104;
  static const double episodeSeasonWidthTv = 72;
  static const double episodeSeasonHeight = 156;
  static const double episodeSeasonHeightTv = 108;
  static const double episodeCardWidth = 268;
  static const double episodeCardWidthTv = 180;
  static const double heroPillHeight = ShellTokens.controlHeight;
  static const double heroPillHeightTv = ShellTokens.controlHeightTv;
  static const double heroPillIconSize = 20;
  static const double heroPillIconSizeTv = 14;
  static const double watchProviderTileSize = 40;
  static const double watchProviderTileSizeTv = 28;
  static const double watchProviderGap = 8;
  static const double episodeRangeMenuHeight = 44;
  static const double episodeRangeMenuHeightTv = 32;
  static const int episodeRangeMenuMaxRows = 8;
  static const double episodeRangeMenuRadius = 20;
  static const double factsRadius = 12;
  static const double sectionTitleFontSize = 18;
  static const double sectionTitleFontSizeTv = ShellTokens.tvTitleFontSize;
  static const double bodyFontSize = 14;
  static const double bodyFontSizeTv = ShellTokens.tvBodyFontSize;
  static const double metaFontSize = 12;
  static const double metaFontSizeTv = ShellTokens.tvMetaFontSize;
  static const double railsGap = 12;
  static const double railsGapTv = 8;
  static const double railsSectionGap = 24;
  static const double railsSectionGapTv = 14;
  static const double detailsHeaderGap = 8;
  static const double detailsHeaderFontSize = 18;
  static const double detailsHeaderFontSizeTv = ShellTokens.tvTitleFontSize;

  static const double heroTitleBlockHeight = 96;
  static const double heroTitleBlockHeightTv = 64;
  static const double heroMetaBlockHeight = 32;
  static const double heroMetaBlockHeightTv = 22;
  static const double heroActionsBlockHeight = 26;
  static const double heroActionsBlockHeightTv = 20;
  static const double heroTitleSlotReserve = 64;
  static const double heroTitleSlotReserveTv = 40;

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
