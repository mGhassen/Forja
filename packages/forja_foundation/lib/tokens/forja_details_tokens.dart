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
///
/// TV sizes follow [ShellTokens.tvChromeScale] (same weight as catalog cards).
abstract final class DetailsTokens {
  static const double _s = ShellTokens.tvChromeScale;

  /// Extra pull-up for movie details body (cast/trailers) when the host opts in.
  static const double heroBodyOverlap = 120;
  static const double heroBodyOverlapTv = heroBodyOverlap * _s;

  static const double heroContentTopInset = 88;
  static const double heroContentTopInsetTv = heroContentTopInset * _s;
  static const double heroDescriptionWidthFraction = 0.40;

  /// Gap after the hero before the first section, and between every section.
  static const double sectionSpacing = 48;
  static const double sectionSpacingTv = sectionSpacing * _s;

  /// Alias — first section under hero uses the same rhythm as between sections.
  static const double bodyTopSpacing = sectionSpacing;
  static const double bodyTopSpacingTv = sectionSpacingTv;

  /// Title → row gap inside cast / trailers / recommendations on details.
  static const double sectionTitleGap = 16;
  static const double sectionTitleGapTv = sectionTitleGap * _s;
  static const double bodyBottomSpacing = 80;
  static const double bodyBottomSpacingTv = bodyBottomSpacing * _s;

  /// Sources sliding panel on media details (player overlays use
  /// [ShellTokens.playerSidePanelPadding]).
  static const EdgeInsets sourcesPanelPadding = EdgeInsets.fromLTRB(
    16,
    8,
    12,
    12,
  );
  static const EdgeInsets sourcesPanelPaddingTv = EdgeInsets.fromLTRB(
    16 * _s,
    4,
    8,
    6,
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
  static const double castAvatarSizeTv = castAvatarSize * _s;
  static const double castItemWidth = 112;
  static const double castItemWidthTv = castItemWidth * _s;
  static const double castGap = 32;
  static const double castGapTv = castGap * _s;
  static const double trailerCardWidth = 200;
  static const double trailerCardWidthTv = trailerCardWidth * _s;
  static const double episodeSeasonWidth = 104;
  static const double episodeSeasonWidthTv = episodeSeasonWidth * _s;
  static const double episodeSeasonHeight = 156;
  static const double episodeSeasonHeightTv = episodeSeasonHeight * _s;
  static const double episodeCardWidth = 268;
  static const double episodeCardWidthTv = episodeCardWidth * _s;
  static const double heroPillHeight = ShellTokens.controlHeight;
  static const double heroPillHeightTv = ShellTokens.controlHeightTv;
  static const double heroPillIconSize = 20;
  static const double heroPillIconSizeTv = heroPillIconSize * _s;
  static const double heroPillLabelPadEnd = 14;
  static const double heroPillLabelPadEndTv = heroPillLabelPadEnd * _s;
  static const double heroPillGap = 10;
  static const double heroPillGapTv = heroPillGap * _s;

  /// Space between pin bottom and floating My List status menu top.
  /// Follower uses [Alignment.bottomLeft] → [Alignment.topLeft] + this gap —
  /// do not bake pin height into the offset (TV pills are shorter).
  static const double listStatusMenuGap = 6;
  static const double listStatusMenuGapTv = listStatusMenuGap * _s;

  static double listStatusMenuGapOf(bool tv) =>
      tv ? listStatusMenuGapTv : listStatusMenuGap;

  /// Floating details back chevron (host [MediaDetailsBackButton]).
  static const double backIconSize = 28;
  static const double backIconSizeTv = backIconSize * _s;
  static const double backHitPad = 12;
  static const double backHitPadTv = backHitPad * _s;

  static double backIconSizeOf(bool tv) =>
      tv ? backIconSizeTv : backIconSize;

  static double backHitSizeOf(bool tv) =>
      backIconSizeOf(tv) + (tv ? backHitPadTv : backHitPad);

  static const double watchProviderTileSize = 40;
  static const double watchProviderTileSizeTv = watchProviderTileSize * _s;
  static const double watchProviderGap = 8;
  static const double episodeRangeMenuHeight = 44;
  static const double episodeRangeMenuHeightTv = episodeRangeMenuHeight * _s;
  static const int episodeRangeMenuMaxRows = 8;
  static const double episodeRangeMenuRadius = 20;

  /// Number-chip episode grid (details Episode list → Number chips).
  static const double episodeChipMinWidth = 48;
  static const double episodeChipMinWidthTv = episodeChipMinWidth * _s;
  static const double episodeChipHeight = 40;
  static const double episodeChipHeightTv = episodeChipHeight * _s;
  static const double episodeChipGap = 8;
  static const double episodeChipGapTv = episodeChipGap * _s;
  static const double episodeChipRadius = 10;
  static const double episodeChipRadiusTv = episodeChipRadius * _s;
  static const int episodeChipColumnsMin = 4;
  static const int episodeChipColumnsMax = 12;

  /// Right-column production facts card on the details hero.
  static const double factsMaxWidth = 300;
  static const double factsMaxWidthTv = factsMaxWidth * _s;
  static const double factsPadH = 20;
  static const double factsPadHTv = factsPadH * _s;
  static const double factsPadVEdge = 16;
  static const double factsPadVEdgeTv = factsPadVEdge * _s;
  static const double factsPadVMid = 10;
  static const double factsPadVMidTv = factsPadVMid * _s;
  static const double factsRadius = 12;
  static const double factsRadiusTv = factsRadius * _s;
  static const double factsFontSize = 13;

  static const double sectionTitleFontSize = 18;
  static const double sectionTitleFontSizeTv = ShellTokens.tvTitleFontSize;
  static const double bodyFontSize = 14;
  static const double bodyFontSizeTv = ShellTokens.tvBodyFontSize;
  static const double metaFontSize = 12;
  static const double metaFontSizeTv = ShellTokens.tvMetaFontSize;

  /// Details / hero meta chips (PG-13, FILM, SERIES).
  static const double certBadgeFontSize = 11;
  static const double certBadgeFontSizeTv = ShellTokens.tvMetaFontSize;
  static const double certBadgePadH = 6;
  static const double certBadgePadHTv = certBadgePadH * _s;
  static const double certBadgePadV = 2;
  static const double certBadgePadVTv = 1;
  static const double certBadgeRadius = 4;
  static const double certBadgeRadiusTv = certBadgeRadius * _s;
  static const double mediaTypeBadgeFontSize = 10;
  static const double mediaTypeBadgeFontSizeTv = ShellTokens.tvMetaFontSize;
  static const double mediaTypeBadgePadH = 8;
  static const double mediaTypeBadgePadHTv = mediaTypeBadgePadH * _s;
  static const double mediaTypeBadgePadV = 3;
  static const double mediaTypeBadgePadVTv = 2;
  static const double mediaTypeBadgeRadius = 4;
  static const double mediaTypeBadgeRadiusTv = mediaTypeBadgeRadius * _s;

  static const double railsGap = 12;
  static const double railsGapTv = railsGap * _s;
  static const double railsSectionGap = 24;
  static const double railsSectionGapTv = railsSectionGap * _s;
  static const double detailsHeaderGap = 8;
  static const double detailsHeaderFontSize = 18;
  static const double detailsHeaderFontSizeTv = ShellTokens.tvTitleFontSize;

  static const double heroTitleBlockHeight = 96;
  static const double heroTitleBlockHeightTv = heroTitleBlockHeight * _s;
  static const double heroMetaBlockHeight = 32;
  static const double heroMetaBlockHeightTv = heroMetaBlockHeight * _s;
  static const double heroActionsBlockHeight = 26;
  static const double heroActionsBlockHeightTv = heroActionsBlockHeight * _s;
  static const double heroTitleSlotReserve = 64;
  static const double heroTitleSlotReserveTv = heroTitleSlotReserve * _s;

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
