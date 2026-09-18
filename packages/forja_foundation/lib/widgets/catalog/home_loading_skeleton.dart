import 'package:flutter/material.dart';
import 'package:forja_foundation/blocks/shell/catalog_density.dart';
import 'package:forja_foundation/components/skeleton.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_section_title.dart';
import 'package:forja_foundation/widgets/feedback/catalog_loading_ticker.dart';

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
  double width = 190,
  double height = 285,
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
  double cardGap = ShellTokens.posterCardRowGap,
  /// Omit → caller should pass [InteractivePosterCard] sizes (desktop ~190×285).
  double cardWidth = 190,
  double cardHeight = 285,
  double borderRadius = 14,
  /// When set, paints real section title (structure-stable) instead of a bar.
  String? title,
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
          child: title != null && title.trim().isNotEmpty
              ? ShellSectionTitle(
                  title: title.trim(),
                  padding: EdgeInsets.zero,
                )
              : Column(
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

/// Title line height used by [ShellSectionTitle.titleStyle] (fontSize 20).
const double kCatalogSectionTitleLineHeight = 24;

/// Reserved height for a density-aware poster rail skeleton (title + cards).
double catalogPosterRowSkeletonHeight({
  required BuildContext context,
  required double cardHeight,
  bool compact = false,
  bool showSubtitle = false,
}) {
  final titleTop = catalogSectionTitleTop(context, compact: compact);
  final bottomGap = catalogSectionBottomGap(context);
  final titleBlock =
      showSubtitle ? kCatalogSectionTitleLineHeight + 2 + 14 : kCatalogSectionTitleLineHeight;
  return titleTop + titleBlock + bottomGap + cardHeight;
}

/// Poster rail skeleton using [catalog_density] tokens — matches live section chrome.
Widget catalogPosterRowSkeleton({
  required BuildContext context,
  String? title,
  double titleWidth = 140,
  int itemCount = 5,
  bool showSubtitle = false,
  bool compact = false,
  double cardWidth = 190,
  double cardHeight = 285,
  double borderRadius = 14,
  bool shimmer = true,
}) {
  final row = homePosterRowSkeleton(
    title: title,
    titleWidth: titleWidth,
    itemCount: itemCount,
    showSubtitle: showSubtitle,
    topPadding: catalogSectionTitleTop(context, compact: compact),
    horizontalPadding: catalogSectionHorizontalPadding(context),
    titleBottomGap: catalogSectionBottomGap(context),
    cardWidth: cardWidth,
    cardHeight: cardHeight,
    borderRadius: borderRadius,
  );
  return shimmer ? homeLoadingShimmer(row) : row;
}

/// Mood chips row + optional results rail height reservation.
Widget catalogMoodRowSkeleton({
  required BuildContext context,
  String? title,
  bool compact = false,
  double chipRowHeight = 122,
  double? resultsCardHeight,
  double resultsCardWidth = 190,
  int chipCount = 6,
  int resultCount = 5,
  bool shimmer = true,
}) {
  final hPad = catalogSectionHorizontalPadding(context);
  final titleTop = catalogSectionTitleTop(context, compact: compact);
  final bottomGap = catalogSectionBottomGap(context);
  final body = Padding(
    padding: EdgeInsets.only(top: titleTop),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(hPad, 0, hPad, bottomGap),
          child: title != null && title.trim().isNotEmpty
              ? ShellSectionTitle(title: title.trim(), padding: EdgeInsets.zero)
              : homeTitleBarSkeleton(width: 160),
        ),
        SizedBox(
          height: chipRowHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: hPad),
            itemCount: chipCount,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, _) => Column(
              children: [
                Skeleton(
                  width: 72,
                  height: 72,
                  borderRadius: BorderRadius.circular(36),
                ),
                const SizedBox(height: 8),
                homeTitleBarSkeleton(width: 56, height: 12),
              ],
            ),
          ),
        ),
        if (resultsCardHeight != null) ...[
          const SizedBox(height: 12),
          homeCatalogCardRowSkeleton(
            itemCount: resultCount,
            horizontalPadding: hPad,
            cardWidth: resultsCardWidth,
            cardHeight: resultsCardHeight,
          ),
        ],
      ],
    ),
  );
  return shimmer ? homeLoadingShimmer(body) : body;
}

double catalogMoodRowSkeletonHeight({
  required BuildContext context,
  bool compact = false,
  double chipRowHeight = 122,
  double? resultsCardHeight,
}) {
  final titleTop = catalogSectionTitleTop(context, compact: compact);
  final bottomGap = catalogSectionBottomGap(context);
  var h = titleTop + kCatalogSectionTitleLineHeight + bottomGap + chipRowHeight;
  if (resultsCardHeight != null) {
    h += 12 + resultsCardHeight;
  }
  return h;
}

/// Because row using density tokens.
Widget catalogBecauseRowSkeleton({
  required BuildContext context,
  bool compact = false,
  int itemCount = 5,
  double cardWidth = 190,
  double cardHeight = 285,
  bool shimmer = true,
}) {
  final row = homeBecauseRowSkeleton(
    itemCount: itemCount,
    topPadding: catalogSectionTitleTop(context, compact: compact),
    horizontalPadding: catalogSectionHorizontalPadding(context),
    titleBottomGap: catalogSectionBottomGap(context),
    cardWidth: cardWidth,
    cardHeight: cardHeight,
  );
  return shimmer ? homeLoadingShimmer(row) : row;
}

double catalogBecauseRowSkeletonHeight({
  required BuildContext context,
  required double cardHeight,
  bool compact = false,
}) {
  // Seed header ~50 tall; title block uses that max.
  final titleTop = catalogSectionTitleTop(context, compact: compact);
  final bottomGap = catalogSectionBottomGap(context);
  return titleTop + 50 + bottomGap + cardHeight;
}

/// Continue Watching row using density tokens.
Widget catalogContinueRowSkeleton({
  required BuildContext context,
  bool compact = false,
  String? title,
  bool shimmer = true,
}) {
  final wide = MediaQuery.sizeOf(context).width >=
      ShellTokens.heroDesktopMinBodyWidth;
  final cardW = catalogContinueCardWidth(context, wide: wide);
  final cardH = catalogContinueCardHeight(context, wide: wide);
  final hPad = catalogSectionHorizontalPadding(context);
  final titleTop = catalogSectionTitleTop(context, compact: compact);
  final bottomGap = catalogSectionBottomGap(context);
  final body = Padding(
    padding: EdgeInsets.only(top: titleTop),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(hPad, 0, hPad, bottomGap),
          child: title != null && title.trim().isNotEmpty
              ? ShellSectionTitle(title: title.trim(), padding: EdgeInsets.zero)
              : homeTitleBarSkeleton(width: 160),
        ),
        SizedBox(
          height: cardH,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: hPad),
            itemCount: 4,
            separatorBuilder: (_, _) =>
                const SizedBox(width: ShellTokens.posterCardRowGap),
            itemBuilder: (_, _) => homeCardSkeleton(
              width: cardW,
              height: cardH,
            ),
          ),
        ),
      ],
    ),
  );
  return shimmer ? homeLoadingShimmer(body) : body;
}

double catalogContinueRowSkeletonHeight({
  required BuildContext context,
  bool compact = false,
}) {
  final wide = MediaQuery.sizeOf(context).width >=
      ShellTokens.heroDesktopMinBodyWidth;
  final cardH = catalogContinueCardHeight(context, wide: wide);
  return catalogPosterRowSkeletonHeight(
    context: context,
    cardHeight: cardH,
    compact: compact,
  );
}

/// Full-page wait while pack layout resolves — solid fill + ticker.
///
/// No invented rails and no elevated band / shimmer (those read as the page
/// background flashing on cold hub remount).
Widget hubNeutralLoadingSkeleton(BuildContext context) {
  return const ColoredBox(
    color: ForjaShellColors.bgDark,
    child: CatalogLoadingTicker(
      title: 'Loading',
      detail: 'Opening this hub…',
    ),
  );
}

/// Matches [BecauseSection] header: 36×50 seed poster + two title lines.
Widget homeBecauseTitleSkeleton() {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Skeleton(
        width: 36,
        height: 50,
        borderRadius: BorderRadius.circular(6),
      ),
      const SizedBox(width: 12),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // "Because you watched" — 11.5 / w700
          homeTitleBarSkeleton(width: 118, height: 12),
          const SizedBox(height: 2),
          // Seed title — 19 / w800
          homeTitleBarSkeleton(width: 168, height: 19),
        ],
      ),
    ],
  );
}

/// Because row shimmer — seed+title header structure + poster cards.
Widget homeBecauseRowSkeleton({
  int itemCount = 5,
  double topPadding = 36,
  double horizontalPadding = ShellTokens.homeSectionHorizontalPadding,
  double titleBottomGap = 16,
  double cardGap = ShellTokens.posterCardRowGap,
  double cardWidth = 190,
  double cardHeight = 285,
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
          child: homeBecauseTitleSkeleton(),
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
  double cardGap = ShellTokens.posterCardRowGap,
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
  double cardGap = ShellTokens.posterCardRowGap,
  double cardWidth = 190,
  double cardHeight = 285,
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
  bool pageBottomBleed = false,
}) {
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
  final cardW = catalogCardWidth ?? ShellTokens.posterCardWidthDesktop;
  final cardH = catalogCardHeight ??
      (ShellTokens.posterCardWidthDesktop * ShellTokens.posterCardAspectRatio)
          .roundToDouble();
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
            cardWidth: cardW,
            cardHeight: cardH,
          ),
        ),
      ),
    ],
  ];
}
