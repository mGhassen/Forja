import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/home_movie_card.dart';

Widget homeLoadingShimmer(Widget child) {
  return Shimmer.fromColors(
    baseColor: AppTheme.bgCard,
    highlightColor: ForjaShellColors.borderSubtle,
    child: child,
  );
}

Widget homeTitleBarSkeleton(BuildContext context, {double width = 140, double? height}) {
  final h = height ?? shellScaled(context, 18).clamp(10.0, 18.0);
  return Container(
    height: h,
    width: shellScaled(context, width).clamp(60.0, width),
    decoration: BoxDecoration(
      color: AppTheme.bgCard,
      borderRadius: BorderRadius.circular(shellScaled(context, 6).clamp(3.0, 6.0)),
    ),
  );
}

Widget homeCardSkeleton(BuildContext context, {double? width}) {
  final cardWidth = width ?? HomeMovieCard.cardWidth(context);
  return Container(
    width: cardWidth,
    height: HomeMovieCard.cardHeight(context),
    decoration: BoxDecoration(
      color: AppTheme.bgCard,
      borderRadius: BorderRadius.circular(shellCardBorderRadius(context)),
    ),
  );
}

bool homeUsesShellLayout(BuildContext context) => shellUsesWideLayout(context);

double homeSectionTitleTop(
  BuildContext context, {
  bool compactTop = false,
}) =>
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
}) {
  final top = topPadding > 0
      ? topPadding
      : homeSectionTitleTop(context, compactTop: compactTop);
  final cardHeight = HomeMovieCard.cardHeight(context);
  final hPad = shellHomeSectionHorizontalPadding(context);

  return Padding(
    padding: EdgeInsets.only(top: top),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            hPad,
            0,
            hPad,
            shellHomeSectionBottomGap(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              homeTitleBarSkeleton(context, width: titleWidth),
              if (showSubtitle) ...[
                SizedBox(height: shellScaled(context, 6).clamp(3.0, 6.0)),
                homeTitleBarSkeleton(context, width: 90, height: 12),
              ],
            ],
          ),
        ),
        SizedBox(
          height: cardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: hPad),
            itemCount: itemCount,
            separatorBuilder: (_, _) =>
                SizedBox(width: shellMovieCardRowGap(context)),
            itemBuilder: (_, _) => homeCardSkeleton(context),
          ),
        ),
      ],
    ),
  );
}

Widget homeContinueWatchingSkeleton(
  BuildContext context, {
  bool compactTop = false,
}) {
  final top = homeSectionTitleTop(context, compactTop: compactTop);
  final cardHeight = homeContinueWatchingCardHeight(context);
  final cardWidth = homeContinueWatchingCardWidth(context);
  final hPad = shellHomeSectionHorizontalPadding(context);

  return homeLoadingShimmer(
    Padding(
      padding: EdgeInsets.only(top: top),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              hPad,
              0,
              hPad,
              shellHomeSectionBottomGap(context),
            ),
            child: homeTitleBarSkeleton(context, width: 160),
          ),
          SizedBox(
            height: cardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: hPad),
              itemCount: 4,
              separatorBuilder: (_, _) =>
                  SizedBox(width: shellMovieCardRowGap(context)),
              itemBuilder: (_, _) => Container(
                width: cardWidth,
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius:
                      BorderRadius.circular(shellCardBorderRadius(context)),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget homeCatalogCardRowSkeleton(BuildContext context, {int itemCount = 5}) {
  return SizedBox(
    height: HomeMovieCard.cardHeight(context),
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: shellHomeSectionHorizontalPadding(context),
      ),
      itemCount: itemCount,
      separatorBuilder: (_, _) =>
          SizedBox(width: shellMovieCardRowGap(context)),
      itemBuilder: (_, _) => homeCardSkeleton(context),
    ),
  );
}

double homeCinematicHeroBodyHeight(
  BuildContext context, {
  required bool compact,
}) {
  if (compact) {
    final screenH = MediaQuery.sizeOf(context).height;
    final target = screenH * ShellTokens.heroHeightFractionCompact;
    return math.max(ShellTokens.heroMinHeightCompact, target);
  }
  return MediaQuery.sizeOf(context).height * shellHeroHeightFraction(context);
}

Widget homeCinematicHeroShimmer(BuildContext context) {
  final compact =
      MediaQuery.sizeOf(context).width < ShellTokens.heroDesktopMinBodyWidth;
  final height = homeCinematicHeroBodyHeight(context, compact: compact) +
      MediaQuery.paddingOf(context).top;
  return homeHubHeroShimmer(height: height);
}

Widget homeHubHeroShimmer({required double height}) {
  return homeLoadingShimmer(
    Container(height: height, color: AppTheme.bgCard),
  );
}

typedef HomeHubLoadingRowSpec = ({double width, bool showSubtitle});

const List<HomeHubLoadingRowSpec> kHomeHubDefaultLoadingRows = [
  (width: 170, showSubtitle: false),
  (width: 160, showSubtitle: false),
  (width: 150, showSubtitle: false),
  (width: 180, showSubtitle: false),
  (width: 165, showSubtitle: false),
];

const List<HomeHubLoadingRowSpec> kHomeHubAsianDramaLoadingRows = [
  (width: 180, showSubtitle: true),
  (width: 150, showSubtitle: false),
  (width: 140, showSubtitle: false),
  (width: 160, showSubtitle: false),
  (width: 130, showSubtitle: false),
  (width: 145, showSubtitle: false),
];

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
        if (!isFirstAfterHero)
          SizedBox(height: shellHomeRowSpacing(context)),
        RepaintBoundary(child: section),
      ],
    ),
  );
}

List<Widget> homeHubLoadingSlivers(
  BuildContext context, {
  required Widget heroShimmer,
  List<HomeHubLoadingRowSpec>? rows,
}) {
  final specs = rows ?? kHomeHubDefaultLoadingRows;
  return [
    SliverToBoxAdapter(child: heroShimmer),
    homeHubRowSliver(
      context,
      homeContinueWatchingSkeleton(context),
      isFirstAfterHero: true,
    ),
    for (final spec in specs)
      homeHubRowSliver(
        context,
        homeLoadingShimmer(
          homeMovieRowSkeleton(
            context,
            titleWidth: spec.width,
            showSubtitle: spec.showSubtitle,
          ),
        ),
        isFirstAfterHero: false,
      ),
  ];
}
