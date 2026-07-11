import 'package:flutter/material.dart';

import 'package:forja/shared/design/src/shell_profile.dart';
import 'package:forja/shared/design/src/shell_scope.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';

/// True when [ShellScope] resolved the TV profile (nav-rail TV chrome).
bool isTvProfile(BuildContext context) =>
    ShellScope.profileOf(context) == ShellProfile.tv;

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

double shellHubCardTitleFontSize(BuildContext context) =>
    ShellScope.metricsOf(context).hubCardTitleFontSize;

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
