import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:forja/shared/shell/forja_shell_layout.dart';
import 'package:forja/shared/shell/forja_shell_scope.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja/shared/shell/movie_poster_card.dart';
import 'package:forja_foundation/widgets/catalog/home_loading_skeleton.dart'
    as ds;

export 'package:forja_foundation/widgets/catalog/home_loading_skeleton.dart'
    show
        HomeHubLoadingRowSpec,
        kHomeHubDefaultLoadingRows,
        kHomeHubAsianDramaLoadingRows;

typedef HomeHubLoadingRowSpec = ds.HomeHubLoadingRowSpec;

Widget homeLoadingShimmer(Widget child) => ds.homeLoadingShimmer(child);

Widget homeTitleBarSkeleton(
  BuildContext context, {
  double width = 140,
  double? height,
}) {
  final h = height ?? shellScaled(context, 18).clamp(10.0, 18.0);
  const minWidth = 60.0;
  final maxWidth = math.max(minWidth, width);
  return ds.homeTitleBarSkeleton(
    width: shellScaled(context, width).clamp(minWidth, maxWidth),
    height: h,
  );
}

Widget homeCardSkeleton(
  BuildContext context, {
  double? width,
  double? height,
}) {
  return ds.homeCardSkeleton(
    width: width ?? MoviePosterCard.cardWidth(context),
    height: height ?? MoviePosterCard.cardHeight(context),
    borderRadius: shellCardBorderRadius(context),
  );
}

bool homeUsesShellLayout(BuildContext context) => shellUsesWideLayout(context);

double homeSectionTitleTop(BuildContext context, {bool compactTop = false}) =>
    shellHomeSectionTitleTop(context, compact: compactTop);

double homeContinueWatchingCardWidth(BuildContext context) =>
    shellContinueWatchingCardWidth(context);

double homeContinueWatchingCardHeight(BuildContext context) =>
    shellContinueWatchingCardHeight(context);

Widget homeMovieRowSkeleton(
  BuildContext context, {
  bool compactTop = false,
  double titleWidth = 140,
  int itemCount = 5,
  bool showSubtitle = false,
  double topPadding = 0,
  double? cardWidth,
  double? cardHeight,
}) {
  final top = topPadding > 0
      ? topPadding
      : homeSectionTitleTop(context, compactTop: compactTop);
  return ds.homeMovieRowSkeleton(
    titleWidth: titleWidth,
    itemCount: itemCount,
    showSubtitle: showSubtitle,
    topPadding: top,
    horizontalPadding: shellHomeSectionHorizontalPadding(context),
    titleBottomGap: shellHomeSectionBottomGap(context),
    cardGap: shellMovieCardRowGap(context),
    cardWidth: cardWidth ?? MoviePosterCard.cardWidth(context),
    cardHeight: cardHeight ?? MoviePosterCard.cardHeight(context),
    borderRadius: shellCardBorderRadius(context),
  );
}

Widget homeContinueWatchingSkeleton(
  BuildContext context, {
  bool compactTop = false,
}) {
  return ds.homeContinueWatchingSkeleton(
    topPadding: homeSectionTitleTop(context, compactTop: compactTop),
    horizontalPadding: shellHomeSectionHorizontalPadding(context),
    titleBottomGap: shellHomeSectionBottomGap(context),
    cardGap: shellMovieCardRowGap(context),
    cardWidth: homeContinueWatchingCardWidth(context),
    cardHeight: homeContinueWatchingCardHeight(context),
    borderRadius: shellCardBorderRadius(context),
  );
}

Widget homeCatalogCardRowSkeleton(BuildContext context, {int itemCount = 5}) {
  return ds.homeCatalogCardRowSkeleton(
    itemCount: itemCount,
    horizontalPadding: shellHomeSectionHorizontalPadding(context),
    cardGap: shellMovieCardRowGap(context),
    cardWidth: MoviePosterCard.cardWidth(context),
    cardHeight: MoviePosterCard.cardHeight(context),
    borderRadius: shellCardBorderRadius(context),
  );
}

double homeCinematicHeroBodyHeight(
  BuildContext context, {
  required bool compact,
  bool pageBottomBleed = false,
}) {
  return ds.homeCinematicHeroBodyHeight(
    screenHeight: MediaQuery.sizeOf(context).height,
    compact: compact,
    pageBottomBleed: pageBottomBleed,
  );
}

Widget homeCinematicHeroShimmer(
  BuildContext context, {
  bool pageBottomBleed = false,
}) {
  final compact =
      !ShellScope.metricsOf(context).usesTvDensity &&
      MediaQuery.sizeOf(context).width < ShellTokens.heroDesktopMinBodyWidth;
  final height =
      homeCinematicHeroBodyHeight(
        context,
        compact: compact,
        pageBottomBleed: pageBottomBleed && !compact,
      ) +
      MediaQuery.paddingOf(context).top;
  return ds.homeHubHeroShimmer(height: height);
}

Widget homeHubHeroShimmer({required double height}) =>
    ds.homeHubHeroShimmer(height: height);

SliverToBoxAdapter homeHubRowSliver(
  BuildContext context,
  Widget section, {
  required bool isFirstAfterHero,
}) {
  return SliverToBoxAdapter(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isFirstAfterHero) SizedBox(height: shellHomeRowSpacing(context)),
        RepaintBoundary(child: section),
      ],
    ),
  );
}

List<Widget> homeHubLoadingSlivers(
  BuildContext context, {
  required Widget heroShimmer,
  List<HomeHubLoadingRowSpec>? rows,
  double? catalogCardWidth,
  double? catalogCardHeight,
}) {
  final specs = rows ?? ds.kHomeHubDefaultLoadingRows;
  return [
    for (final w in ds.homeHubLoadingSlivers(
      heroShimmer: heroShimmer,
      rows: specs,
      catalogCardWidth: catalogCardWidth ?? MoviePosterCard.cardWidth(context),
      catalogCardHeight:
          catalogCardHeight ?? MoviePosterCard.cardHeight(context),
      rowSpacing: shellHomeRowSpacing(context),
    ))
      w,
  ];
}
