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
  if (catalogUsesTvDensity(context)) {
    return ShellTokens.continueWatchingCardWidthTv;
  }
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

/// Category / side rail — iso desktop width on TV (not poster-ratio shrink).
double catalogSideRailWidth(BuildContext context) => ShellTokens.categoryRailWidth;

double catalogControlHeight(BuildContext context) =>
    catalogUsesTvDensity(context)
        ? ShellTokens.controlHeightTv
        : ShellTokens.controlHeight;

double catalogHomeTopBarHeight(BuildContext context) =>
    catalogUsesTvDensity(context)
        ? ShellTokens.homeTopBarHeightTv
        : ShellTokens.homeTopBarHeight;

/// Iso desktop category row metrics on TV (same extent / type as desktop).
double catalogCategoryRailRowExtent(BuildContext context, {bool compact = false}) {
  return compact
      ? ShellTokens.categoryRailRowExtentCompact
      : ShellTokens.categoryRailRowExtent;
}

double catalogCategoryRailFontSize(BuildContext context, {bool compact = false}) {
  return compact
      ? ShellTokens.categoryRailFontSizeCompact
      : ShellTokens.categoryRailFontSize;
}

double catalogCategoryRailIconSize(BuildContext context, {bool compact = false}) {
  return compact
      ? ShellTokens.categoryRailIconSizeCompact
      : ShellTokens.categoryRailIconSize;
}

double catalogProviderTileWidth(BuildContext context) =>
    catalogUsesTvDensity(context)
        ? ShellTokens.shellProviderTileWidthTv
        : ShellTokens.shellProviderTileWidth;

double catalogProviderTileHeight(BuildContext context) =>
    catalogUsesTvDensity(context)
        ? ShellTokens.shellProviderTileHeightTv
        : ShellTokens.shellProviderTileHeight;

double catalogProviderRailWidth(BuildContext context) =>
    catalogUsesTvDensity(context)
        ? ShellTokens.shellProviderRailWidthTv
        : ShellTokens.shellProviderRailWidth;

double catalogProviderRailInset(BuildContext context) =>
    catalogUsesTvDensity(context)
        ? ShellTokens.shellProviderRailInsetTv
        : ShellTokens.shellProviderRailInset;

double catalogCategoryRailListPadV(BuildContext context) =>
    ShellTokens.categoryRailListPadV;

double catalogCategoryRailRowPadH(BuildContext context, {bool compact = false}) {
  return compact
      ? ShellTokens.categoryRailRowPadHCompact
      : ShellTokens.categoryRailRowPadH;
}

double catalogCategoryRailRowPadV(BuildContext context, {bool compact = false}) {
  return compact
      ? ShellTokens.categoryRailRowPadVCompact
      : ShellTokens.categoryRailRowPadV;
}

double catalogCategoryRailPinSlotWidth(BuildContext context) =>
    ShellTokens.categoryRailPinSlotWidth;
