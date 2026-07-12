import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:forja/shared/design/src/shell_metrics.dart';
import 'package:forja/shared/design/src/shell_profile.dart';
import 'package:forja/shared/design/src/shell_scope.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';

/// True when [ShellScope] resolved the TV profile (nav-rail TV chrome).
bool isTvProfile(BuildContext context) =>
    ShellScope.profileOf(context) == ShellProfile.tv;

/// System overscan inset (when the device reports padding) — applied once in
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

/// Wide hub/search/mylist layout (nav-rail spacing, two-column search, dense grids).
bool shellUsesWideLayout(BuildContext context) {
  final profile = ShellScope.profileOf(context);
  if (profile != ShellProfile.mobile) return true;
  return MediaQuery.sizeOf(context).width > ShellTokens.musicDesktopBreakpoint;
}

double shellMovieCardWidth(BuildContext context) {
  if (ShellScope.profileOf(context) == ShellProfile.mobile) {
    return MediaQuery.sizeOf(context).width > 900 ? 190.0 : 165.0;
  }
  return ShellScope.metricsOf(context).homeMovieCardWidth;
}

double shellMovieCardHeight(BuildContext context) =>
    (shellMovieCardWidth(context) * 1.5).roundToDouble();

double shellContinueWatchingCardWidth(BuildContext context) =>
    ShellScope.metricsOf(context).continueWatchingCardWidth;

double shellContinueWatchingCardHeight(BuildContext context) =>
    ShellScope.metricsOf(context).continueWatchingCardHeight;

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

double shellHomeSectionHorizontalPadding(BuildContext context) =>
    ShellScope.metricsOf(context).usesTvDensity
        ? ShellTokens.tvHomeSectionHorizontalPadding
        : ShellTokens.homeSectionHorizontalPadding;

double shellHomeRowSpacing(BuildContext context) =>
    ShellScope.metricsOf(context).usesTvDensity
        ? ShellTokens.tvHomeRowSpacing
        : ShellTokens.homeRowSpacing;

double shellHeroHeightFraction(BuildContext context) =>
    ShellScope.metricsOf(context).usesTvDensity
        ? ShellTokens.tvHeroHeightFraction
        : ShellTokens.heroHeightFractionDesktop;

double shellMovieCardRowGap(BuildContext context) =>
    ShellScope.metricsOf(context).usesTvDensity
        ? ShellTokens.tvMovieCardRowGap
        : 14.0;

/// Horizontal inset so TV focus scale + border stay inside layout bounds.
double shellMovieCardFocusBleed(
  BuildContext context, {
  double scaleOnFocus = ShellTokens.focusActiveScale,
}) {
  const borderWidth = 1.5;
  if (scaleOnFocus <= 1.0) return borderWidth + 1;
  final w = shellMovieCardWidth(context);
  return w * (scaleOnFocus - 1) / 2 + borderWidth + 1;
}

double shellHomeSectionTitleTop(
  BuildContext context, {
  bool compact = false,
}) {
  if (compact) return shellSectionTitleTopCompact(context);
  if (ShellScope.metricsOf(context).usesTvDensity) {
    return ShellTokens.tvHomeSectionTitleTop;
  }
  return ShellTokens.homeSectionTitleTop;
}

double shellHomeSectionHeaderHeight(BuildContext context) =>
    ShellScope.metricsOf(context).usesTvDensity
        ? ShellTokens.tvHomeSectionHeaderHeight
        : 28.0;

double shellHomeSectionBottomGap(BuildContext context) =>
    ShellScope.metricsOf(context).usesTvDensity
        ? ShellTokens.tvHomeSectionBottomGap
        : 16.0;

double shellCatalogSectionHeight(
  BuildContext context, {
  bool compactTop = false,
  required double cardHeight,
}) {
  return shellHomeSectionTitleTop(context, compact: compactTop) +
      shellHomeSectionHeaderHeight(context) +
      shellHomeSectionBottomGap(context) +
      cardHeight;
}

double shellHeroNextRowPeekFraction(BuildContext context) =>
    ShellScope.metricsOf(context).usesTvDensity
        ? ShellTokens.tvHeroNextRowPeekFraction
        : ShellTokens.heroNextRowPeekFraction;

double shellHeroMinHeight(BuildContext context) =>
    ShellScope.metricsOf(context).usesTvDensity ? 400.0 : 320.0;

double shellSearchGridCardWidth(BuildContext context) => shellMovieCardWidth(context);

int shellGridCrossAxisCount(
  BuildContext context, {
  int phone = 3,
  int tablet = 4,
  int wide = 6,
}) {
  if (shellUsesWideLayout(context)) return wide;
  final w = MediaQuery.sizeOf(context).width;
  return w > 600 ? tablet : phone;
}

bool shellIptvUsesWideLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= 1100;

/// TV density vs desktop card baseline (190px). Typography uses [ShellTokens.tvLayoutScaleFloor].
double shellLayoutScale(BuildContext context) {
  if (!ShellScope.metricsOf(context).usesTvDensity) return 1.0;
  final raw = ShellScope.metricsOf(context).homeMovieCardWidth /
      ShellMetrics.desktop.homeMovieCardWidth;
  return math.max(ShellTokens.tvLayoutScaleFloor, raw);
}

double shellHeroMetaGap(BuildContext context) =>
    ShellScope.metricsOf(context).usesTvDensity ? 14.0 : 10.0;

double shellHeroActionGap(BuildContext context) =>
    ShellScope.metricsOf(context).usesTvDensity ? 16.0 : 12.0;

double shellScaled(BuildContext context, double value) =>
    value * shellLayoutScale(context);

double shellCardBorderRadius(BuildContext context) =>
    shellScaled(context, 14).clamp(4.0, 14.0);

EdgeInsets shellSectionTitlePadding(BuildContext context) {
  final h = shellHomeSectionHorizontalPadding(context);
  return EdgeInsets.fromLTRB(
    h,
    shellHomeSectionTitleTop(context),
    h,
    shellHomeSectionBottomGap(context),
  );
}

EdgeInsets shellHomeSectionTitlePadding(
  BuildContext context, {
  double? top,
  double? bottom,
}) {
  final h = shellHomeSectionHorizontalPadding(context);
  return EdgeInsets.fromLTRB(
    h,
    top ?? shellHomeSectionTitleTop(context),
    h,
    bottom ?? shellHomeSectionBottomGap(context),
  );
}

double shellNavRailIconSize(BuildContext context) =>
    shellScaled(context, ShellTokens.navRailIconSize)
        .clamp(20.0, ShellTokens.navRailIconSize);

double shellNavRailLabelFontSize(BuildContext context) =>
    shellScaled(context, ShellTokens.navRailLabelFontSize)
        .clamp(11.0, ShellTokens.navRailLabelFontSize);

double shellNavRailItemContentHeight(BuildContext context) {
  final icon = shellNavRailIconSize(context);
  return icon * ShellTokens.navRailIconHoverScale +
      ShellTokens.navRailIconUnderlineGap +
      ShellTokens.shellNavUnderlineHeight +
      ShellTokens.navRailIconLabelGap +
      shellNavRailLabelFontSize(context);
}

TextStyle shellSectionTitleTextStyle(BuildContext context) => TextStyle(
      color: Colors.white,
      fontSize: shellScaled(context, 20).clamp(15.0, 20.0),
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
    );

TextStyle shellSectionSubtitleTextStyle(BuildContext context) => TextStyle(
      color: Colors.white.withValues(alpha: 0.3),
      fontSize: shellScaled(context, 11).clamp(10.0, 11.0),
    );
