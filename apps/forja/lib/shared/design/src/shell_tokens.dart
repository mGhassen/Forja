import 'dart:io' show Platform;

import 'package:flutter/material.dart';

/// Layout constants for the app shell nav chrome.
abstract final class ShellTokens {
  static const double bottomNavHeight = 80;
  static const double bottomNavItemWidth = 100;
  static const double bottomNavIconPaddingH = 20;
  static const double bottomNavIconPaddingV = 4;
  static const double bottomNavLabelSize = 11;
  static const double bottomNavFadeWidth = 40;

  /// Fixed desktop nav rail width (no hover expand).
  static const double navRailWidth = 120;

  /// Below this window width the nav rail collapses to a menu button + drawer.
  static const double shellNavCompactMaxWidth = 1000;

  /// Width reserved for the shell menu button when the rail is collapsed.
  static const double shellNavMenuButtonWidth = 56;
  static const double navRailIconSize = 30;
  /// Immediate hover grow for rail icons (and compact ☰).
  static const double navRailIconHoverScale = 1.15;
  static const double navRailIconRevealedScale = 0.78;
  static const double navRailIconSlideUp = 10;
  static const double navRailIconLabelGap = 3;
  static const double navRailLabelFontSize = 11;
  static const double navRailItemSpacing = 28;
  static const Duration navRailLabelRevealDelay = Duration(seconds: 3);
  static const Duration navRailIconScaleAnimation = Duration(milliseconds: 520);
  static const Duration navRailLabelLetterInterval = Duration(milliseconds: 72);
  static const Duration navRailLabelRevealAnimation = Duration(milliseconds: 520);

  static const double shellButtonHeight = 40;
  static const double shellButtonRadius = 6;
  static const double shellNavUnderlineHeight = 3;
  static const double shellHeaderTopPadding = 16;
  static const double navRailLogoWidth = 80;
  static const double navRailLogoHeight = navRailLogoWidth * 160 / 370;
  static const double shellCategoryUnderlineGap = 6;
  static const double shellProviderCardWidth = 132;
  static const double shellProviderCardHeight = 74;
  static const double shellProviderCardRadius = 6;
  static const double shellProviderCardGap = 4;
  static const double shellProviderHoverScale = 1.18;
  static const double shellProviderCenterFocusThreshold = 1.35;
  static const int shellProviderVisibleCount = 5;
  static const double shellProviderEdgePeekFraction = 0.5;
  static const double shellProviderRowRightInset = 0;

  static const double shellProviderStripHeight =
      shellProviderCardHeight * shellProviderHoverScale + 4;

  /// Width of the top-bar provider strip (center cards + half-card peeks on edges).
  static double get shellProviderRowViewportWidth {
    final cardSlots =
        shellProviderVisibleCount + shellProviderEdgePeekFraction * 2;
    return cardSlots * shellProviderCardWidth + (cardSlots - 1) * shellProviderCardGap;
  }

  static const double shellTopBarHeight = shellProviderStripHeight + 20;

  /// Home Films / TV / Categories text menu (not provider strip).
  static const double homeTopBarHeight =
      shellHeaderTopPadding + 34 + shellCategoryUnderlineGap + shellNavUnderlineHeight;

  /// Extra inset before the Films tab in [HomeTopBar].
  static const double homeTopBarMenuLeadingInset = 28;

  /// Home Categories popup: visible rows before scrolling.
  static const double homeCategoriesMenuRowHeight = 38;
  static const int homeCategoriesMenuMaxVisibleRows = 8;
  static double get homeCategoriesMenuMaxHeight =>
      homeCategoriesMenuRowHeight * homeCategoriesMenuMaxVisibleRows;
  static const double shellLogoWidth = 110;

  /// Music desktop sidebar width — global rail hidden when Music tab uses this.
  static const double musicDesktopSidebarWidth = 260;
  static const double musicDesktopBreakpoint = 900;

  /// Minimum Home body width for the full cinematic hero; narrower uses compact hero.
  static const double heroDesktopMinBodyWidth = 1000;

  static const double heroHeightFractionCompact = 0.50;
  static const double heroMinHeightCompact = 280;
  static const double heroLogoMaxHeightCompact = 72;
  static const double heroTitleSlotHeightCompact = 80;
  static const double heroImageStartFractionCompact = 0.08;

  static const double heroImageStartFraction = 0.20;
  static const double heroImageWidthFraction = 0.80;
  static const double heroTextWidthFraction = heroImageStartFraction;

  /// Opaque overlay band after the image starts (fraction of image-strip width).
  /// Prefer [heroImageStartFraction] to widen the text column; non-zero values
  /// can show a vertical edge where the flat overlay meets the fade.
  static const double heroImageGradientSolidEndFraction = 0.0;

  /// Horizontal fade on the image strip: solidEnd → this fraction of image width
  /// (shell bg → transparent). Was 0.58; ~46% of total hero width at 20% start.
  static const double heroImageGradientFadeEndFraction = 0.72;
  static const double heroHeightFractionDesktop = 0.72;
  static const double heroMoodHeaderOverlapFraction = 1 / 3;

  /// Fraction of the second Home row visible below the first (desktop cinematic).
  static const double heroNextRowPeekFraction = 0.10;

  /// Fraction of the first Home row pulled under the desktop hero bottom.
  static const double heroFirstRowOverlapFraction = 0.10;

  /// Continue Watching horizontal card (16:9 landscape).
  static const double shellContinueWatchingCardWidthDesktop = 280;
  static const double shellContinueWatchingCardHeightDesktop =
      shellContinueWatchingCardWidthDesktop * 9 / 16;
  static const double shellContinueWatchingCardWidthCompact = 240;
  static const double shellContinueWatchingCardHeightCompact =
      shellContinueWatchingCardWidthCompact * 9 / 16;

  /// Continue Watching section height on desktop (header + landscape row).
  static const double heroContinueWatchingHeightDesktop =
      16 + 30 + 16 + shellContinueWatchingCardHeightDesktop;

  /// Mood section header block before chips (padding + title row + padding).
  static const double heroMoodHeaderTopHeightDesktop = 36 + 44 + 12;

  /// Pull Continue Watching into the hero; hero bottom lands ~1/3 into mood header.
  static double get heroBackdropOverlapDesktop {
    final moodOverlap =
        heroMoodHeaderTopHeightDesktop * heroMoodHeaderOverlapFraction;
    return (heroContinueWatchingHeightDesktop + moodOverlap) / 2;
  }

  static const double heroTextColumnWidthDesktop = 480;

  /// Top inset for hero text: clears [homeTopBarHeight] plus breathing room.
  static double get heroTextColumnTopInsetDesktop => homeTopBarHeight + 16;
  /// Vertical align for hero text within the hero band (-1 top … 1 bottom).
  static const double heroTextColumnVerticalAlign = -0.82;
  static const double heroTitleSlotHeightDesktop = 196;
  static const double heroMetaSlotHeightDesktop = 40;
  static const double heroMetaOverviewGapDesktop = 32;
  static const int heroOverviewMaxLinesDesktop = 3;
  static const double heroOverviewFontSizeDesktop = 17;
  static const double heroOverviewLineHeightDesktop = 1.55;
  static const double heroOverviewReadMoreGap = 8;

  /// Fixed overview block — keeps action row stable across hero slides.
  static double get heroOverviewSlotHeightDesktop =>
      heroOverviewFontSizeDesktop *
          heroOverviewLineHeightDesktop *
          heroOverviewMaxLinesDesktop +
      heroOverviewReadMoreGap +
      heroOverviewFontSizeDesktop * heroOverviewLineHeightDesktop;
  static const double heroLogoMaxHeightDesktop = 180;

  /// Narrow right-edge vignette on flat cinematic body (desktop Home).
  static const double bodyRightGradientWidth = 88;

  static const double bodyHorizontalPadding = 20;
  static const double bodyMaxWidthDesktop = 1600;

  /// Horizontal inset for home catalog rows ([ShellSectionTitle], poster lists).
  static const double homeSectionHorizontalPadding = 24;

  /// Media details — body below full-bleed hero (hero stays edge-to-edge).
  static const double detailsHeroBodyOverlap = 120;
  /// Extra pull-up when the TV episode rail sits in the first viewport.
  static const double detailsHeroBodyOverlapWithEpisodes = 168;
  static const double detailsHeroContentTopInset = 88;
  static const double detailsHeroDescriptionWidthFraction = 0.40;
  static const double detailsBodyTopSpacing = 36;
  static const double detailsBodyTopSpacingWithEpisodes = 12;
  static const double detailsSectionSpacing = 48;
  static const double detailsBodyBottomSpacing = 80;
  static const double detailsContentPaddingDesktop = homeSectionHorizontalPadding;
  static const double detailsContentPaddingCompact = homeSectionHorizontalPadding;

  static double detailsContentHorizontalPadding(double viewportWidth) {
    if (viewportWidth >= shellNavCompactMaxWidth) {
      return detailsContentPaddingDesktop;
    }
    return detailsContentPaddingCompact;
  }

  static double detailsContentLeftInset(double viewportWidth) {
    final padding = detailsContentHorizontalPadding(viewportWidth);
    final columnWidth =
        viewportWidth < bodyMaxWidthDesktop ? viewportWidth : bodyMaxWidthDesktop;
    final sideGutter = (viewportWidth - columnWidth) / 2;
    return sideGutter + padding;
  }

  /// Cinematic hero band (~82% viewport) — see media-details feature doc.
  static const double detailsHeroViewportFraction = 0.82;

  /// Shorter hero when the TV episode rail must peek into the first screen.
  static const double detailsHeroWithEpisodesFraction = 0.68;

  /// Hero height for media details — prefer [viewportHeight] from a [LayoutBuilder].
  static double detailsHeroHeight(
    BuildContext context, {
    double? viewportHeight,
    bool showEpisodeRail = false,
  }) {
    final height = viewportHeight ?? MediaQuery.sizeOf(context).height;
    final resolved = height.isFinite && height > 0
        ? height
        : MediaQuery.sizeOf(context).height;
    final fraction = showEpisodeRail
        ? detailsHeroWithEpisodesFraction
        : detailsHeroViewportFraction;
    return resolved * fraction;
  }

  static const double tabHeaderTopPadding = 16;
  static const double tabHeaderBottomPadding = 12;
  static const double tabHeaderFontSize = 32;

  static const double sectionTopSpacing = 20;

  /// Vertical gap between Home content rows (not hero → first row).
  static const double homeRowSpacing = 24;

  /// Title top inset for a standard Home row (pairs with [homeRowSpacing]).
  static const double homeSectionTitleTop = 36;
  static const double homeSectionTitleTopCompactDesktop = 16;
  static const double homeSectionTitleTopCompactMobile = 32;
  static const double searchCardWidthDesktop = 140;
  static const double searchCardWidthCompact = 120;

  /// Netflix-style search: input column on desktop.
  static const double searchPageInset = 32;
  /// Top inset for desktop search — aligns with Home hero text clearance.
  static double get searchPageTopInset => homeTopBarHeight + 24;
  static const double searchColumnGap = 32;
  static const double searchLeftColumnWidth = 420;
  static const double searchLeftColumnPadding = 16;
  static const double searchProviderRowHeight = 52;
  static const double searchProviderCardWidth = 88;
  static const double searchProviderCardHeight = 48;
  static const double searchDetailPosterWidth = 120;
  static const double searchDetailPosterHeight = 180;
  static const double settingsSectionBottomSpacing = 8;
  static const double settingsSectionTitleSize = 15;
  static const double settingsSectionRadius = 14;

  static const Duration navSelectionAnimation = Duration(milliseconds: 200);
  static const double navSelectionBorderRadius = 16;

  /// Max tabs kept mounted in [MainScreen] (home + current always kept).
  static const int maxMountedTabs = 5;

  /// Default stale TTL before re-select / resume triggers [ShellTabRefresh].
  static const Duration tabStaleDefault = Duration(minutes: 15);

  static const Duration tabStaleHome = Duration(minutes: 15);
  static const Duration tabStaleAudiobooks = Duration(minutes: 10);
  static const Duration tabStaleDiscover = Duration(minutes: 15);
  static const Duration tabStaleIptv = Duration(minutes: 10);
  static const Duration tabStaleMusic = Duration(minutes: 10);
  static const Duration tabStaleJellyfin = Duration(minutes: 15);

  @Deprecated('Use navRailWidth')
  static const double navRailCollapsedWidth = navRailWidth;

  @Deprecated('Use navRailWidth')
  static const double navRailExpandedWidth = navRailWidth;

  /// Android TV / leanback: wide landscape with tablet-class shortest side.
  static bool isTvLayout(BuildContext context) {
    if (!Platform.isAndroid) return false;
    final size = MediaQuery.sizeOf(context);
    if (size.shortestSide < 600) return false;
    return size.longestSide >= 960 && size.width > size.height;
  }
}
