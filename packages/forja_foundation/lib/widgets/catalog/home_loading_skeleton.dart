import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja_foundation/blocks/shell/catalog_density.dart';
import 'package:forja_foundation/components/mood_circle.dart';
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
  double? chipRowHeight,
  double? resultsCardHeight,
  double resultsCardWidth = 190,
  int chipCount = 6,
  int resultCount = 5,
  bool shimmer = true,
}) {
  final hPad = catalogSectionHorizontalPadding(context);
  final titleTop = catalogSectionTitleTop(context, compact: compact);
  final bottomGap = catalogSectionBottomGap(context);
  final resolvedChipRowHeight = chipRowHeight ??
      (catalogUsesTvDensity(context)
          ? ShellTokens.moodCircleRowHeightTv
          : MoodCircleLayout.desktop.rowHeight);
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
          height: resolvedChipRowHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: hPad),
            itemCount: chipCount,
            separatorBuilder: (_, _) => SizedBox(
              width: catalogUsesTvDensity(context)
                  ? ShellTokens.moodCircleGapTv
                  : 12,
            ),
            itemBuilder: (_, _) {
              final tv = catalogUsesTvDensity(context);
              final circle = tv
                  ? ShellTokens.moodCircleSizeTv
                  : 72.0;
              final labelW = tv
                  ? ShellTokens.moodCircleItemWidthTv
                  : 56.0;
              final labelGap = tv
                  ? ShellTokens.moodCircleLabelGapTv
                  : 8.0;
              final labelH = tv ? ShellTokens.tvMetaFontSize : 12.0;
              return Column(
                children: [
                  Skeleton(
                    width: circle,
                    height: circle,
                    borderRadius: BorderRadius.circular(circle / 2),
                  ),
                  SizedBox(height: labelGap),
                  homeTitleBarSkeleton(width: labelW, height: labelH),
                ],
              );
            },
          ),
        ),
        if (resultsCardHeight != null) ...[
          SizedBox(height: ShellTokens.chromeScale(12, tv: catalogUsesTvDensity(context))),
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
  double? chipRowHeight,
  double? resultsCardHeight,
}) {
  final titleTop = catalogSectionTitleTop(context, compact: compact);
  final bottomGap = catalogSectionBottomGap(context);
  final resolvedChipRowHeight = chipRowHeight ??
      (catalogUsesTvDensity(context)
          ? ShellTokens.moodCircleRowHeightTv
          : MoodCircleLayout.desktop.rowHeight);
  var h =
      titleTop + kCatalogSectionTitleLineHeight + bottomGap + resolvedChipRowHeight;
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
///
/// [tabId] flavors the copy when known; otherwise cycles a short cinematic pool.
Widget hubNeutralLoadingSkeleton(BuildContext context, {String? tabId}) {
  return ColoredBox(
    color: ForjaShellColors.bgDark,
    child: _HubLoadingTicker(tabId: tabId?.trim() ?? ''),
  );
}

class _HubLoadingTicker extends StatefulWidget {
  const _HubLoadingTicker({required this.tabId});

  final String tabId;

  @override
  State<_HubLoadingTicker> createState() => _HubLoadingTickerState();
}

class _HubLoadingTickerState extends State<_HubLoadingTicker> {
  static const _pool = <(String, String)>[
    ('Cueing the reel', 'Rolling the opening titles…'),
    ('Dim the house lights', 'Bringing this hub into focus…'),
    ('Warming the projector', 'Lining up the shelves…'),
    ('Hold for curtain', 'The next screen is almost ready…'),
    ('Setting the stage', "Gathering what's on tonight…"),
    ("Marquee's warming up", 'Finding something worth the seat…'),
  ];

  late List<(String, String)> _lines;
  late int _index;
  Timer? _rotate;

  @override
  void initState() {
    super.initState();
    final flavored = _flavoredForTab(widget.tabId);
    _lines = flavored == null ? _pool : [flavored, ..._pool];
    _index = 0;
    _rotate = Timer.periodic(const Duration(milliseconds: 3200), (_) {
      if (!mounted || _lines.length < 2) return;
      setState(() => _index = (_index + 1) % _lines.length);
    });
  }

  @override
  void dispose() {
    _rotate?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pair = _lines[_index];
    return CatalogLoadingTicker(title: pair.$1, detail: pair.$2);
  }
}

(String, String)? _flavoredForTab(String tabId) {
  switch (tabId) {
    case 'home':
      return ('Home', 'Lining up your shelves…');
    case 'anime':
      return ('Anime', 'Queuing the next binge…');
    case 'asian_drama':
      return ('Asian Drama', "Cueing tonight's episode…");
    case 'iptv':
      return ('Live TV', 'Tuning your portals…');
    case 'live_sports':
    case 'live_sports_cards':
      return ('Live Sports', "Checking today's fixtures…");
    case 'my_list':
      return ('My List', 'Opening your list…');
    case 'kids':
      return ('Kids', 'Finding something fun…');
    default:
      return null;
  }
}

/// Matches [BecauseSection] header: 36×50 seed poster + two title lines.
Widget homeBecauseTitleSkeleton() {
  return Builder(
    builder: (context) {
      final tv = catalogUsesTvDensity(context);
      final seedW = ShellTokens.chromeScale(36, tv: tv);
      final seedH = ShellTokens.chromeScale(50, tv: tv);
      final gap = ShellTokens.chromeScale(12, tv: tv);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Skeleton(
            width: seedW,
            height: seedH,
            borderRadius: BorderRadius.circular(
              ShellTokens.chromeScale(6, tv: tv),
            ),
          ),
          SizedBox(width: gap),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              homeTitleBarSkeleton(
                width: ShellTokens.chromeScale(118, tv: tv),
                height: tv ? ShellTokens.tvMetaFontSize : 12,
              ),
              SizedBox(height: ShellTokens.chromeScale(2, tv: tv)),
              homeTitleBarSkeleton(
                width: ShellTokens.chromeScale(168, tv: tv),
                height: tv ? ShellTokens.tvTitleFontSize : 19,
              ),
            ],
          ),
        ],
      );
    },
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
