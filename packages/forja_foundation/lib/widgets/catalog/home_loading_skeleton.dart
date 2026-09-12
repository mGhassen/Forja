import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:forja_foundation/components/skeleton.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Lightweight shimmer wrapper (no third-party deps).
Widget homeLoadingShimmer(Widget child) {
  return _PulseShimmer(child: child);
}

class _PulseShimmer extends StatefulWidget {
  const _PulseShimmer({required this.child});

  final Widget child;

  @override
  State<_PulseShimmer> createState() => _PulseShimmerState();
}

class _PulseShimmerState extends State<_PulseShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        return Opacity(
          opacity: 0.55 + _c.value * 0.45,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

Widget homeTitleBarSkeleton({
  double width = 140,
  double height = 18,
}) {
  return Skeleton(
    width: width,
    height: height,
    borderRadius: BorderRadius.circular(6),
  );
}

Widget homeCardSkeleton({
  double width = 120,
  double height = 180,
  double borderRadius = 14,
}) {
  return Skeleton(
    width: width,
    height: height,
    borderRadius: BorderRadius.circular(borderRadius),
  );
}

Widget homePosterRowSkeleton({
  double titleWidth = 140,
  int itemCount = 5,
  bool showSubtitle = false,
  double topPadding = 36,
  double horizontalPadding = ShellTokens.homeSectionHorizontalPadding,
  double titleBottomGap = 16,
  double cardGap = 14,
  double cardWidth = 120,
  double cardHeight = 180,
  double borderRadius = 14,
}) {
  return Padding(
    padding: EdgeInsets.only(top: topPadding),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            0,
            horizontalPadding,
            titleBottomGap,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              homeTitleBarSkeleton(width: titleWidth),
              if (showSubtitle) ...[
                const SizedBox(height: 6),
                homeTitleBarSkeleton(width: 90, height: 12),
              ],
            ],
          ),
        ),
        SizedBox(
          height: cardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            itemCount: itemCount,
            separatorBuilder: (_, _) => SizedBox(width: cardGap),
            itemBuilder: (_, _) => homeCardSkeleton(
              width: cardWidth,
              height: cardHeight,
              borderRadius: borderRadius,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget homeContinueWatchingSkeleton({
  double topPadding = 36,
  double horizontalPadding = ShellTokens.homeSectionHorizontalPadding,
  double titleBottomGap = 16,
  double cardGap = 14,
  double cardWidth = ShellTokens.shellContinueWatchingCardWidthDesktop,
  double cardHeight = ShellTokens.shellContinueWatchingCardHeightDesktop,
  double borderRadius = 14,
}) {
  return homeLoadingShimmer(
    Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              0,
              horizontalPadding,
              titleBottomGap,
            ),
            child: homeTitleBarSkeleton(width: 160),
          ),
          SizedBox(
            height: cardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              itemCount: 4,
              separatorBuilder: (_, _) => SizedBox(width: cardGap),
              itemBuilder: (_, _) => homeCardSkeleton(
                width: cardWidth,
                height: cardHeight,
                borderRadius: borderRadius,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget homeCatalogCardRowSkeleton({
  int itemCount = 5,
  double horizontalPadding = ShellTokens.homeSectionHorizontalPadding,
  double cardGap = 14,
  double cardWidth = 120,
  double cardHeight = 180,
  double borderRadius = 14,
}) {
  return SizedBox(
    height: cardHeight,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      itemCount: itemCount,
      separatorBuilder: (_, _) => SizedBox(width: cardGap),
      itemBuilder: (_, _) => homeCardSkeleton(
        width: cardWidth,
        height: cardHeight,
        borderRadius: borderRadius,
      ),
    ),
  );
}

double homeCinematicHeroBodyHeight({
  required double screenHeight,
  required bool compact,
  bool pageBottomBleed = false,
}) {
  if (compact) {
    final target = screenHeight * ShellTokens.heroHeightFractionCompact;
    return math.max(ShellTokens.heroMinHeightCompact, target);
  }
  if (pageBottomBleed) {
    return screenHeight * ShellTokens.homeBackdropViewportFraction +
        ShellTokens.homePageBottomSectionDownOffset;
  }
  return screenHeight * ShellTokens.heroHeightFractionDesktop;
}

Widget homeCinematicHeroShimmer({
  required double height,
}) {
  return homeHubHeroShimmer(height: height);
}

Widget homeHubHeroShimmer({required double height}) {
  return homeLoadingShimmer(
    Container(height: height, color: ForjaShellColors.surfaceElevated),
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

List<Widget> homeHubLoadingSlivers({
  required Widget heroShimmer,
  List<HomeHubLoadingRowSpec>? rows,
  double? catalogCardWidth,
  double? catalogCardHeight,
  double rowSpacing = ShellTokens.homeRowSpacing,
}) {
  final specs = rows ?? kHomeHubDefaultLoadingRows;
  return [
    SliverToBoxAdapter(child: heroShimmer),
    SliverToBoxAdapter(
      child: homeContinueWatchingSkeleton(
        cardWidth: catalogCardWidth ??
            ShellTokens.shellContinueWatchingCardWidthDesktop,
        cardHeight: catalogCardHeight ??
            ShellTokens.shellContinueWatchingCardHeightDesktop,
      ),
    ),
    for (var i = 0; i < specs.length; i++) ...[
      SliverToBoxAdapter(child: SizedBox(height: rowSpacing)),
      SliverToBoxAdapter(
        child: homeLoadingShimmer(
          homePosterRowSkeleton(
            titleWidth: specs[i].width,
            showSubtitle: specs[i].showSubtitle,
            cardWidth: catalogCardWidth ?? 120,
            cardHeight: catalogCardHeight ?? 180,
          ),
        ),
      ),
    ],
  ];
}
