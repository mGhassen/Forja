import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/home_movie_card.dart';

Widget homeLoadingShimmer(Widget child) {
  return Shimmer.fromColors(
    baseColor: AppTheme.bgCard,
    highlightColor: const Color(0xFF1E1E2F),
    child: child,
  );
}

Widget homeTitleBarSkeleton({double width = 140, double height = 18}) {
  return Container(
    height: height,
    width: width,
    decoration: BoxDecoration(
      color: AppTheme.bgCard,
      borderRadius: BorderRadius.circular(6),
    ),
  );
}

Widget homeCardSkeleton(BuildContext context, {double? width}) {
  return Container(
    width: width ?? HomeMovieCard.cardWidth(context),
    decoration: BoxDecoration(
      color: AppTheme.bgCard,
      borderRadius: BorderRadius.circular(14),
    ),
  );
}

bool homeUsesShellLayout(BuildContext context) {
  if (!kIsWeb &&
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    return true;
  }
  return MediaQuery.sizeOf(context).width > ShellTokens.musicDesktopBreakpoint;
}

double homeSectionTitleTop(
  BuildContext context, {
  bool compactTop = false,
}) {
  if (!compactTop) return ShellTokens.homeSectionTitleTop;
  return homeUsesShellLayout(context)
      ? ShellTokens.homeSectionTitleTopCompactDesktop
      : ShellTokens.homeSectionTitleTopCompactMobile;
}

double homeContinueWatchingCardWidth(BuildContext context) {
  final isDesktop =
      MediaQuery.sizeOf(context).width > ShellTokens.musicDesktopBreakpoint;
  return isDesktop
      ? ShellTokens.shellContinueWatchingCardWidthDesktop
      : ShellTokens.shellContinueWatchingCardWidthCompact;
}

double homeContinueWatchingCardHeight(BuildContext context) {
  final isDesktop =
      MediaQuery.sizeOf(context).width > ShellTokens.musicDesktopBreakpoint;
  return isDesktop
      ? ShellTokens.shellContinueWatchingCardHeightDesktop
      : ShellTokens.shellContinueWatchingCardHeightCompact;
}

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

  return Padding(
    padding: EdgeInsets.only(top: top),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
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
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: itemCount,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
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

  return homeLoadingShimmer(
    Padding(
      padding: EdgeInsets.only(top: top),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: homeTitleBarSkeleton(width: 160),
          ),
          SizedBox(
            height: cardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: 4,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (_, _) => Container(
                width: cardWidth,
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget homeHubHeroShimmer({required double height}) {
  return homeLoadingShimmer(
    Container(height: height, color: AppTheme.bgCard),
  );
}
