import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:forja/shared/design/src/shell_scope.dart';

/// Layout constants for shell chrome, Home hero, and catalog surfaces.
///
/// Media-details layout lives in `DetailsTokens` (`details_tokens.dart`).
abstract final class ShellTokens {
  static const double bottomNavHeight = 88;
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

  /// Horizontal space for the macOS traffic-light cluster (hidden title bar).
  static const double macTrafficLightLeadingInset = 78;

  /// True only when the shell actually shows ☰ + drawer (not merely narrow).
  ///
  /// TV keeps the rail at every width (`allowCompactNavDrawer: false`) — do not
  /// treat those layouts as compact chrome or tab bars get a false hamburger inset.
  static bool usesCompactNavDrawer(BuildContext context) {
    final metrics = ShellScope.maybeOf(context)?.metrics;
    if (metrics != null && !metrics.allowCompactNavDrawer) return false;
    return MediaQuery.sizeOf(context).width < shellNavCompactMaxWidth;
  }

  /// Left edge for compact ☰ - clears macOS traffic lights.
  static double compactMenuLeadingInset(BuildContext context) {
    final mac = Platform.isMacOS ? macTrafficLightLeadingInset : 0.0;
    return math.max(bodyHorizontalPadding, mac);
  }

  /// Left inset for tab chrome that follows compact ☰ (menu lane + button).
  static double compactChromeLeadingInset(BuildContext context) {
    if (!usesCompactNavDrawer(context)) return bodyHorizontalPadding;
    return compactMenuLeadingInset(context) + shellNavMenuButtonWidth;
  }

  static const double navRailIconSize = 36;

  /// Floor when TV compresses the rail to fit every enabled tab.
  static const double navRailIconSizeMin = 22;

  /// Profile avatar vs nav icon (desktop hover rail).
  static const double navRailProfileAvatarScaleDesktop = 1.65;

  /// Profile avatar vs nav icon on Android TV — smaller, sits nearer the bottom.
  static const double navRailProfileAvatarScaleTv = 1.1;

  /// Resting rail icon scale (below [navRailIconSize]).
  static const double navRailIconIdleScale = 0.82;

  /// Immediate hover / focus grow for rail icons (and compact ☰).
  static const double navRailIconHoverScale = 1.28;

  /// Gap between icon and selection underline in the nav rail.
  static const double navRailIconUnderlineGap = 2;

  /// D-pad / TV focus scale.
  static const double focusActiveScale = 1.08;
  static const double navRailIconRevealedScale = 0.78;
  static const double navRailIconSlideUp = 10;
  static const double navRailIconLabelGap = 3;
  static const double navRailLabelFontSize = 11;
  static const double navRailItemSpacing = 28;
  static const Duration navRailLabelRevealDelay = Duration(milliseconds: 300);
  static const Duration navRailIconScaleAnimation = Duration(milliseconds: 520);
  static const Duration navRailLabelLetterInterval = Duration(milliseconds: 72);
  static const Duration navRailLabelRevealAnimation = Duration(
    milliseconds: 520,
  );

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
    return cardSlots * shellProviderCardWidth +
        (cardSlots - 1) * shellProviderCardGap;
  }

  static const double shellTopBarHeight = shellProviderStripHeight + 20;

  /// Home Films / TV / Categories text menu (not provider strip).
  static const double homeTopBarHeight =
      shellHeaderTopPadding +
      34 +
      shellCategoryUnderlineGap +
      shellNavUnderlineHeight;

  /// Extra inset before the Films tab in [HomeTopBar].
  static const double homeTopBarMenuLeadingInset = 28;

  /// Home Categories popup: visible rows before scrolling.
  static const double homeCategoriesMenuRowHeight = 38;
  static const int homeCategoriesMenuMaxVisibleRows = 8;
  static double get homeCategoriesMenuMaxHeight =>
      homeCategoriesMenuRowHeight * homeCategoriesMenuMaxVisibleRows;
  static const double shellLogoWidth = 110;

  /// Music desktop sidebar width - global rail hidden when Music tab uses this.
  static const double musicDesktopSidebarWidth = 260;
  static const double musicDesktopBreakpoint = 900;

  /// Minimum Home body width for the full cinematic hero; narrower uses compact hero.
  static const double heroDesktopMinBodyWidth = 1000;

  static const double heroHeightFractionCompact = 0.50;
  static const double heroMinHeightCompact = 280;
  static const double heroLogoMaxHeightCompact = 72;
  static const double heroTitleSlotHeightCompact = 80;
  static const double heroImageStartFractionCompact = 0.08;

  static const double heroImageStartFraction = 0.12;
  static const double heroImageWidthFraction = 0.88;
  static const double heroTextWidthFraction = heroImageStartFraction;

  /// Opaque overlay band after the image starts (fraction of image-strip width).
  /// Prefer [heroImageStartFraction] to widen the text column; non-zero values
  /// can show a vertical edge where the flat overlay meets the fade.
  static const double heroImageGradientSolidEndFraction = 0.0;

  /// Horizontal fade on the image strip: solidEnd → this fraction of image width
  /// (shell bg → transparent). Was 0.58; ~63% of total hero width at 12% start.
  static const double heroImageGradientFadeEndFraction = 0.72;
  static const double heroHeightFractionDesktop = 0.72;

  /// Home desktop/TV - page backdrop height (hero chrome + first row on image).
  static const double homeBackdropViewportFraction = 0.90;

  /// Padding above **Featured This Month** when stacked on the hero backdrop.
  static const double homePageBottomSectionTopPadding = 8;

  /// Extra backdrop height below the viewport band so Featured can sit on-image.
  static const double homePageBottomSectionDownOffset = 82;
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
  static const double heroMetaOverviewGapDesktop = 16;
  static const int heroOverviewMaxLinesDesktop = 3;
  static const double heroOverviewFontSizeDesktop = 17;
  static const double heroOverviewLineHeightDesktop = 1.55;
  static const double heroOverviewReadMoreGap = 8;

  /// Overview text lines only (no Read More row).
  static double heroOverviewTextHeightDesktop(int maxLines) =>
      heroOverviewFontSizeDesktop * heroOverviewLineHeightDesktop * maxLines;

  /// Fixed overview block - keeps action row stable across hero slides.
  static double heroOverviewSlotHeightForLines(int maxLines) =>
      heroOverviewTextHeightDesktop(maxLines) +
      heroOverviewReadMoreGap +
      heroOverviewFontSizeDesktop * heroOverviewLineHeightDesktop;

  static double get heroOverviewSlotHeightDesktop =>
      heroOverviewSlotHeightForLines(heroOverviewMaxLinesDesktop);
  static const double heroLogoMaxHeightDesktop = 180;

  /// Narrow right-edge vignette on flat cinematic body (desktop Home).
  static const double bodyRightGradientWidth = 88;

  static const double bodyHorizontalPadding = 20;
  static const double bodyMaxWidthDesktop = 1600;

  /// Horizontal inset for home catalog rows ([ShellSectionTitle], poster lists).
  static const double homeSectionHorizontalPadding = 24;

  /// Right-side sliding panels over the player (Episodes, torrent files).
  /// Media-details Sources uses `DetailsTokens.sourcesPanelPadding`.
  static const EdgeInsets playerSidePanelPadding =
      EdgeInsets.fromLTRB(12, 16, 12, 8);

  static const double tabHeaderTopPadding = 16;
  static const double tabHeaderBottomPadding = 12;
  static const double tabHeaderFontSize = 32;

  static const double sectionTopSpacing = 20;

  /// Vertical gap between Home content rows (not hero → first row).
  static const double homeRowSpacing = 24;

  /// TV catalog spacing - aligned with desktop/detail rhythm (cards stay 90px).
  static const double tvHomeRowSpacing = 20;
  static const double tvHomeSectionHorizontalPadding = 0;
  static const double tvHeroHeightFraction = 0.78;
  static const double tvHeroNextRowPeekFraction = 0.06;

  /// Catalog row D-pad focus: keep this fraction of viewport below the row.
  static const double tvCatalogRowFocusBottomInsetFraction = 0.10;
  static const double tvHomeSectionTitleTopCompact = 16;
  static const double tvHomeSectionTitleTop = 24;
  static const double tvHomeSectionHeaderHeight = 26;
  static const double tvHomeSectionBottomGap = 14;
  static const double tvMovieCardRowGap = 12;

  /// Floor for TV typography/chrome - cards scale down, text/spacing does not crush.
  static const double tvLayoutScaleFloor = 0.75;

  /// Title top inset for a standard Home row (pairs with [homeRowSpacing]).
  static const double homeSectionTitleTop = 36;
  static const double homeSectionTitleTopCompactDesktop = 16;
  static const double homeSectionTitleTopCompactMobile = 32;
  static const double searchCardWidthDesktop = 140;
  static const double searchCardWidthCompact = 120;

  /// Netflix-style search: input column on desktop.
  static const double searchPageInset = 32;

  /// Top inset for desktop search - aligns with Home hero text clearance.
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

  /// Max tabs kept mounted in [MainScreen] on desktop / phone (home + current always kept).
  static const int maxMountedTabsDesktop = 5;

  /// Tighter cap on Android TV — weak SoCs need RAM/GPU for decode after browsing.
  static const int maxMountedTabsTv = 3;

  /// Max tabs kept mounted in [MainScreen] (home + current always kept under normal LRU).
  static int get maxMountedTabs =>
      isAndroidTvDevice ? maxMountedTabsTv : maxMountedTabsDesktop;

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

  static const double tvBodyHorizontalPadding = 0;

  /// Set at boot by [PlatformChannel.initialize] when native leanback reports TV.
  static bool nativeAndroidTvDetected = false;

  /// Android TV / leanback: native leanback detection or 1080p+ landscape panel.
  static bool get isAndroidTvDevice {
    if (!Platform.isAndroid) return false;
    if (nativeAndroidTvDetected) return true;
    final physical = _androidTvPhysicalSize();
    if (physical == null) return false;
    return physical.shortestSide >= 1080 && physical.width > physical.height;
  }

  static bool isTvLayout(BuildContext context) {
    if (isAndroidTvDevice) return true;
    if (!Platform.isAndroid) return false;
    final size = MediaQuery.sizeOf(context);
    if (size.shortestSide < 600) return false;
    return size.longestSide >= 960 && size.width > size.height;
  }

  static Size? _androidTvPhysicalSize() {
    if (!Platform.isAndroid) return null;
    final views = SchedulerBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return null;
    return views.first.physicalSize;
  }
}
