import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:forja/shell/core/forja_shell_metrics.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// True when [ShellScope] resolved the TV profile (nav-rail TV chrome).
bool isTvProfile(BuildContext context) =>
    ShellScope.profileOf(context) == ShellProfile.tv;

/// System overscan inset (when the device reports padding) - applied once in
/// [ShellScaffold]; child [SafeArea] must not add horizontal padding again.
double shellTvSafeHorizontalInset(BuildContext context) {
  if (!isTvProfile(context)) return 0;
  return math.max(
    MediaQuery.paddingOf(context).left,
    ShellTokens.tvBodyHorizontalPadding,
  );
}

double shellTvSafeHorizontalInsetRight(BuildContext context) {
  if (!isTvProfile(context)) return 0;
  return math.max(
    MediaQuery.paddingOf(context).right,
    ShellTokens.tvBodyHorizontalPadding,
  );
}

/// Wide hub/search/lists layout (nav-rail spacing, two-column search, dense grids).
bool shellUsesWideLayout(BuildContext context) {
  final profile = ShellScope.profileOf(context);
  if (profile != ShellProfile.mobile) return true;
  return MediaQuery.sizeOf(context).width > ShellTokens.musicDesktopBreakpoint;
}

double shellPosterCardWidth(BuildContext context) {
  if (ShellScope.profileOf(context) == ShellProfile.mobile) {
    return MediaQuery.sizeOf(context).width > ShellTokens.posterCardWideBreakpoint
        ? ShellTokens.posterCardWidthDesktop
        : ShellTokens.posterCardWidthMobile;
  }
  return ShellScope.metricsOf(context).posterCardWidth;
}

double shellPosterCardHeight(BuildContext context) =>
    (shellPosterCardWidth(context) * ShellTokens.posterCardAspectRatio)
        .roundToDouble();

double shellHubCardTitleFontSize(BuildContext context) =>
    ShellScope.metricsOf(context).hubCardTitleFontSize;

double shellSectionTitleTopCompact(BuildContext context) {
  if (ShellScope.metricsOf(context).usesTvDensity) {
    return ShellTokens.tvHomeSectionTitleTopCompact;
  }
  return shellUsesWideLayout(context)
      ? ShellTokens.homeSectionTitleTopCompactDesktop
      : ShellTokens.homeSectionTitleTopCompactMobile;
}

double shellHeroHeightFraction(BuildContext context) =>
    ShellScope.metricsOf(context).usesTvDensity
    ? ShellTokens.tvHeroHeightFraction
    : ShellTokens.heroHeightFractionDesktop;

double shellPosterCardRowGap(BuildContext context) =>
    ShellScope.metricsOf(context).usesTvDensity
    ? ShellTokens.tvPosterCardRowGap
    : ShellTokens.posterCardRowGap;

/// Horizontal inset so leanback TV focus scale + border stay inside layout bounds.
///
/// Desktop hover must not use this as permanent padding ([FocusableControl]
/// skips it when [ShellInputPolicy.scaleOnHover] is on).
///
/// Pass [cardWidth] for the scaled control; defaults to catalog poster width.
double shellCardFocusBleed(
  BuildContext context, {
  double scaleOnFocus = ShellTokens.focusActiveScale,
  double? cardWidth,
}) {
  const borderWidth = ShellTokens.cardFocusBorderWidth;
  if (scaleOnFocus <= 1.0) {
    return borderWidth + ShellTokens.cardFocusBleedExtra;
  }
  final w = cardWidth ?? shellPosterCardWidth(context);
  return w * (scaleOnFocus - 1) / 2 +
      borderWidth +
      ShellTokens.cardFocusBleedExtra;
}

double shellHeroNextRowPeekFraction(BuildContext context) =>
    ShellScope.metricsOf(context).usesTvDensity
    ? ShellTokens.tvHeroNextRowPeekFraction
    : ShellTokens.heroNextRowPeekFraction;

/// Trailing scroll gap on hub catalog pages so the last TV row can lift on focus.
double shellTvKitScrollBottomGap(BuildContext context) {
  if (ShellScope.metricsOf(context).usesTvDensity) {
    return MediaQuery.sizeOf(context).height *
        ShellTokens.tvKitRowFocusBottomInsetFraction;
  }
  return ShellTokens.kitScrollBottomGapDesktop;
}

double shellHeroMinHeight(BuildContext context) =>
    ShellScope.metricsOf(context).usesTvDensity
    ? ShellTokens.heroMinHeightTv
    : ShellTokens.heroMinHeightDesktop;

double shellSearchGridCardWidth(BuildContext context) =>
    shellPosterCardWidth(context);

int shellGridCrossAxisCount(
  BuildContext context, {
  int phone = 3,
  int tablet = 4,
  int wide = 6,
}) {
  if (shellUsesWideLayout(context)) return wide;
  final w = MediaQuery.sizeOf(context).width;
  return w > ShellTokens.shellGridTabletMinWidth ? tablet : phone;
}

/// TV density vs desktop card baseline. Scale tracks metrics poster width.
double shellLayoutScale(BuildContext context) {
  if (!ShellScope.metricsOf(context).usesTvDensity) return 1.0;
  return ShellScope.metricsOf(context).posterCardWidth /
      ShellMetrics.desktop.posterCardWidth;
}

double shellHeroMetaGap(BuildContext context) =>
    ShellScope.metricsOf(context).usesTvDensity
    ? ShellTokens.heroMetaGapTv
    : ShellTokens.heroMetaGapDesktop;

double shellHeroActionGap(BuildContext context) =>
    ShellScope.metricsOf(context).usesTvDensity
    ? ShellTokens.heroActionGapTv
    : ShellTokens.heroActionGapDesktop;

double shellScaled(BuildContext context, double value) =>
    value * shellLayoutScale(context);

double shellCardBorderRadius(BuildContext context) => shellScaled(
  context,
  ShellTokens.posterCardRadius,
).clamp(ShellTokens.posterCardRadiusMin, ShellTokens.posterCardRadius);

/// Preferred nav icon size. TV density scales down from the desktop token;
/// [_navRailFitForHeight] may compress further so every tab fits.
double shellNavRailIconSize(BuildContext context) =>
    shellScaled(context, ShellTokens.navRailIconSize).clamp(
      ShellTokens.navRailIconSizeTvMin,
      ShellTokens.navRailIconSize,
    );

double shellNavRailLabelFontSize(BuildContext context) =>
    shellScaled(context, ShellTokens.navRailLabelFontSize).clamp(
      ShellTokens.navRailLabelFontSizeTvMin,
      ShellTokens.navRailLabelFontSize,
    );

/// Label row height — includes [MediaQuery.textScalerOf] (Windows accessibility).
double shellNavRailLabelSlotHeight(BuildContext context, [double? baseFontSize]) {
  final base = baseFontSize ?? ShellTokens.navRailLabelFontSize;
  return MediaQuery.textScalerOf(context).scale(base) *
      ShellTokens.navRailLabelLineHeight;
}

double shellNavRailProfileAvatarScale(BuildContext context) =>
    ShellScope.metricsOf(context).usesTvDensity
    ? ShellTokens.navRailProfileAvatarScaleTv
    : ShellTokens.navRailProfileAvatarScaleDesktop;

/// Fixed footprint for one rail item at [iconSize] (hover/focus scale included).
double shellNavRailItemContentHeight(
  BuildContext context, {
  double? iconSize,
  double? labelFontSize,
  double? labelSlotHeight,
}) {
  final icon = iconSize ?? shellNavRailIconSize(context);
  final label =
      labelSlotHeight ?? shellNavRailLabelSlotHeight(context, labelFontSize);
  return icon * ShellTokens.navRailIconHoverScale +
      ShellTokens.navRailIconUnderlineGap +
      ShellTokens.shellNavUnderlineHeight +
      ShellTokens.navRailIconLabelGap +
      label;
}

TextStyle shellSectionTitleTextStyle(BuildContext context) => TextStyle(
  color: Colors.white,
  fontSize: shellScaled(context, ShellTokens.sectionTitleFontSize).clamp(
    ShellTokens.sectionTitleFontSizeMin,
    ShellTokens.sectionTitleFontSize,
  ),
  fontWeight: FontWeight.w800,
  letterSpacing: ShellTokens.sectionTitleLetterSpacing,
);

TextStyle shellSectionSubtitleTextStyle(BuildContext context) => TextStyle(
  color: Colors.white.withValues(alpha: 0.3),
  fontSize: shellScaled(context, ShellTokens.sectionSubtitleFontSize).clamp(
    ShellTokens.sectionSubtitleFontSizeMin,
    ShellTokens.sectionSubtitleFontSize,
  ),
);

/// Desktop cinematic hero text column - prefer synopsis over a full logo slot.
class ShellHeroDesktopTextLayout {
  const ShellHeroDesktopTextLayout({
    required this.titleHeight,
    required this.showOverview,
    required this.overviewMaxLines,
    required this.overviewSlotHeight,
  });

  final double titleHeight;
  final bool showOverview;
  final int overviewMaxLines;
  final double overviewSlotHeight;
}

/// Fits title + optional overview into [maxHeight] for Home / hub heroes.
///
/// When space is tight (Featured / Latest stacked on the backdrop), shrinks the
/// title slot and overview lines before dropping the synopsis entirely.
/// Pass [reservedBelowOverview] for extra chrome under the overview (e.g. upcoming
/// notice) so that height is part of the fit budget.
ShellHeroDesktopTextLayout shellHeroDesktopTextLayout({
  required double maxHeight,
  required bool hasOverview,
  required double minTitleHeight,
  double reservedBelowOverview = 0,
}) {
  const titleGap = ShellTokens.heroTitleMetaGapDesktop;
  const actionGap = ShellTokens.heroMetaActionsGapDesktop;
  final baseWithoutOverview =
      titleGap +
      ShellTokens.heroMetaSlotHeightDesktop +
      actionGap +
      ShellTokens.shellButtonHeight +
      reservedBelowOverview;
  final metaGap = ShellTokens.heroMetaOverviewGapDesktop;

  double slotFor(int lines, {required bool includeReadMore}) {
    final text = ShellTokens.heroOverviewTextHeightDesktop(lines);
    if (!includeReadMore) return text;
    return ShellTokens.heroOverviewSlotHeightForLines(lines);
  }

  bool fits(double titleH, double overviewBlock) =>
      titleH + baseWithoutOverview + overviewBlock <= maxHeight;

  var titleHeight = ShellTokens.heroTitleSlotHeightDesktop;

  if (!hasOverview) {
    if (!fits(titleHeight, 0)) {
      titleHeight = (maxHeight - baseWithoutOverview).clamp(
        minTitleHeight,
        ShellTokens.heroTitleSlotHeightDesktop,
      );
    }
    return ShellHeroDesktopTextLayout(
      titleHeight: titleHeight,
      showOverview: false,
      overviewMaxLines: 0,
      overviewSlotHeight: 0,
    );
  }

  var lines = ShellTokens.heroOverviewMaxLinesDesktop;
  var includeReadMore = true;
  var slot = slotFor(lines, includeReadMore: includeReadMore);
  var overviewBlock = metaGap + slot;

  if (!fits(titleHeight, overviewBlock)) {
    titleHeight = (maxHeight - baseWithoutOverview - overviewBlock).clamp(
      minTitleHeight,
      ShellTokens.heroTitleSlotHeightDesktop,
    );
  }

  while (!fits(titleHeight, overviewBlock) && lines > 1) {
    lines--;
    slot = slotFor(lines, includeReadMore: includeReadMore);
    overviewBlock = metaGap + slot;
    titleHeight = (maxHeight - baseWithoutOverview - overviewBlock).clamp(
      minTitleHeight,
      ShellTokens.heroTitleSlotHeightDesktop,
    );
  }

  // Keep read-more reserve whenever overview shows — HeroOverviewText always
  // paints Read More for truncated copy in fixed slots.
  if (!fits(titleHeight, overviewBlock)) {
    titleHeight = minTitleHeight;
    if (fits(titleHeight, overviewBlock)) {
      return ShellHeroDesktopTextLayout(
        titleHeight: titleHeight,
        showOverview: true,
        overviewMaxLines: lines,
        overviewSlotHeight: slot,
      );
    }
    titleHeight = ShellTokens.heroTitleSlotHeightDesktop;
    if (!fits(titleHeight, 0)) {
      titleHeight = (maxHeight - baseWithoutOverview).clamp(
        minTitleHeight,
        ShellTokens.heroTitleSlotHeightDesktop,
      );
    }
    return ShellHeroDesktopTextLayout(
      titleHeight: titleHeight,
      showOverview: false,
      overviewMaxLines: 0,
      overviewSlotHeight: 0,
    );
  }

  return ShellHeroDesktopTextLayout(
    titleHeight: titleHeight,
    showOverview: true,
    overviewMaxLines: lines,
    overviewSlotHeight: slot,
  );
}
