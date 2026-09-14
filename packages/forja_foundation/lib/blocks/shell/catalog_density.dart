/// Catalog density helpers for kit paint — uses [ShellPaintScope], not product tabs.
library;

import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

bool catalogUsesTvDensity(BuildContext context) =>
    ShellPaintScope.maybeOf(context)?.usesTvDensity ?? false;

double catalogSectionHorizontalPadding(BuildContext context) =>
    catalogUsesTvDensity(context)
        ? ShellTokens.tvHomeSectionHorizontalPadding
        : ShellTokens.homeSectionHorizontalPadding;

double catalogSectionTitleTop(BuildContext context, {bool compact = false}) {
  if (compact) {
    if (catalogUsesTvDensity(context)) {
      return ShellTokens.tvHomeSectionTitleTopCompact;
    }
    return ShellTokens.homeSectionTitleTopCompactDesktop;
  }
  if (catalogUsesTvDensity(context)) {
    return ShellTokens.tvHomeSectionTitleTop;
  }
  return ShellTokens.homeSectionTitleTop;
}

double catalogSectionBottomGap(BuildContext context) =>
    catalogUsesTvDensity(context)
        ? ShellTokens.tvHomeSectionBottomGap
        : 16.0;

double catalogContinueCardWidth(BuildContext context, {required bool wide}) {
  if (catalogUsesTvDensity(context)) return 140;
  return wide
      ? ShellTokens.shellContinueWatchingCardWidthDesktop
      : ShellTokens.shellContinueWatchingCardWidthCompact;
}

double catalogContinueCardHeight(BuildContext context, {required bool wide}) {
  final w = catalogContinueCardWidth(context, wide: wide);
  if (catalogUsesTvDensity(context)) return w * 9 / 16;
  return wide
      ? ShellTokens.shellContinueWatchingCardHeightDesktop
      : ShellTokens.shellContinueWatchingCardHeightCompact;
}
