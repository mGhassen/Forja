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

double shellSectionTitleTopCompact(BuildContext context) =>
    shellUsesWideLayout(context)
        ? ShellTokens.homeSectionTitleTopCompactDesktop
        : ShellTokens.homeSectionTitleTopCompactMobile;

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
