import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Layout constants for shell chrome, Home hero, and catalog surfaces.
///
/// Media-details layout lives in `DetailsTokens` (`forja_details_tokens.dart`).
///
/// Host [ShellScope] wraps the tree in [CompactNavDrawerPolicy] so TV
/// (rail-always) does not get hamburger insets.
abstract final class ShellTokens {
  static const double bottomNavHeight = 88;
  static const double bottomNavItemWidth = 100;
  static const double bottomNavIconPaddingH = 20;
  static const double bottomNavIconPaddingV = 4;
  static const double bottomNavLabelSize = 11;
  static const double bottomNavFadeWidth = 40;
  static const double bottomNavIconLabelGap = 4;
  static const double bottomNavFadeIconSize = 12;

  /// Fixed desktop nav rail width (no hover expand).
  static const double navRailWidth = 120;

  /// Below this window width the nav rail collapses to a menu button + drawer.
  static const double shellNavCompactMaxWidth = 1000;

  /// Width reserved for the shell menu button when the rail is collapsed.
  static const double shellNavMenuButtonWidth = 56;

  /// Horizontal space for the macOS traffic-light cluster (hidden title bar).
  static const double macTrafficLightLeadingInset = 78;

  /// True when the window is narrow enough for ☰ + drawer.
  ///
  /// [CompactNavDrawerPolicy.allow] == false (TV rail-always) wins over width.
  static bool usesCompactNavDrawer(BuildContext context) {
    if (CompactNavDrawerPolicy.maybeAllow(context) == false) return false;
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

  /// Floor for TV density scale ([shellNavRailIconSize]) before fit-to-height.
  static const double navRailIconSizeTvMin = 16;

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

  /// Gap between selection underline and label (TV focus / desktop hover).
  static const double navRailIconLabelGap = 6;

  static const double navRailLabelFontSize = 11;

  /// Floor when TV density scales rail labels.
  static const double navRailLabelFontSizeTvMin = 9;

  /// Line-height multiplier for rail labels — slot must match or glyphs clip.
  static const double navRailLabelLineHeight = 1.2;
  static const double navRailItemSpacing = 28;
  static const double navRailItemSpacingTv = 12;
  static const double navRailItemSpacingMin = 2;
  static const double navRailLogoGapDesktop = 20;
  static const double navRailLogoGapTv = 8;
  static const double navRailBottomPaddingDesktop = 16;
  static const double navRailBottomPaddingTv = 8;
  static const double navRailTopPaddingTv = 8;
  static const double navRailProfileSpacingTv = 4;
  static const double navRailNavPadVTv = 4;
  static const double navRailNavReserveDesktop = 16;
  static const double navRailScrollPadV = 8;
  static const double navRailLogoHoverScale = 1.04;
  static const double navRailLogoTapPadding = 4;
  static const double navRailLogoTapPaddingWide = 8;
  static const double navRailIconPressScale = 0.92;
  static const double shellNavUnderlineWidth = 24;
  static const double shellNavUnderlineWidthMin = 14;
  static const double shellNavUnderlineRadius = 2;
  static const double shellNavMenuButtonHitSize = 34;
  static const double navRailLanMarkGap = 5;
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
  static const double shellProviderCardRadius = 8;
  static const double shellProviderCardGap = 4;
  static const double shellProviderHoverScale = 1.18;
  static const double shellProviderCenterFocusThreshold = 1.35;
  static const int shellProviderVisibleCount = 5;
  static const double shellProviderEdgePeekFraction = 0.5;
  static const double shellProviderRowRightInset = 0;

  /// Vertical Home provider panel (floating next to nav rail).
  /// Desktop: wider rectangle tiles. Top menu mark stays square.
  static const double shellProviderTileWidth = 96;
  static const double shellProviderTileHeight = 54;
  static const double shellProviderTileSize = shellProviderTileHeight;
  static const double shellProviderTileRadius = 6.5;
  static const double shellProviderTopBarLogoInset = 0.14;
  static const double shellProviderRailMaxHeightFraction = 0.88;
  static const Duration shellProviderRailScrollAnimation = Duration(
    milliseconds: 140,
  );
  static const double shellProviderTileSelectedRing = 2;
  static const double shellProviderTileSelectedPad = 2;
  static const double shellProviderTileCheckInset = 4;
  static const double shellProviderTileCheckPad = 2;
  static const double shellProviderTileCheckWidth = 12;
  static const double shellProviderTileCheckHeight = 10;
  static const double shellProviderRailGap = 10;
  static const double shellProviderRailPadH = 12;
  static const double shellProviderRailPadV = 14;
  static const double shellProviderRailWidth =
      shellProviderTileWidth + shellProviderRailPadH * 2;
  static const double shellProviderRailInset = 10;
  static const double shellProviderRailRadius = 18;

  /// Selected-provider mark before Films — rectangle (wordmark-friendly).
  static const double shellProviderTopBarIconWidth = 88;
  static const double shellProviderTopBarIconHeight = 40;
  static const double shellProviderTopBarIconWidthTv = 92;
  static const double shellProviderTopBarIconHeightTv = 42;

  static const double shellProviderStripHeight =
      shellProviderCardHeight * shellProviderHoverScale + 4;

  /// Width of the legacy top-bar provider strip.
  static double get shellProviderRowViewportWidth {
    final cardSlots =
        shellProviderVisibleCount + shellProviderEdgePeekFraction * 2;
    return cardSlots * shellProviderCardWidth +
        (cardSlots - 1) * shellProviderCardGap;
  }

  static const double shellTopBarHeight = shellProviderStripHeight + 20;

  /// Home Films / TV / Categories text menu (not provider strip).
  /// Label band for Films / TV / Categories (underline sits below).
  static const double homeMenuRowHeight = 34;
  static const double homeTopBarHeight =
      shellHeaderTopPadding +
      homeMenuRowHeight +
      shellCategoryUnderlineGap +
      shellNavUnderlineHeight;

  /// Extra inset before the Films tab in [HomeTopBar].
  static const double homeTopBarMenuLeadingInset = 28;

  /// Hoisted `kit.menu` → `kit.tabs` gap in [KitTopBar].
  static const double kitTopBarStatusRowTopGap = 10;
  static const double kitTopBarStatusRowHeight = 42;
  static const double kitTopBarHideSlideDistance = 56;
  static const double kitTopBarTabGapTv = 28;
  static const double kitTopBarTabGapCompact = 20;
  static const double kitTopBarTabGapWide = 36;
  static const double kitTopBarTabGapCompactMaxWidth = 560;
  static const double kitTopBarTabFontSize = 17;
  static const double kitTopBarChevronSize = 18;
  static const double kitTopBarIconGap = 6;
  static const double kitTopBarChevronGap = 4;
  static const double kitTopBarUnderlineHoverWidth = 28;
  static const double kitTopBarUnderlineSelectedExtra = 4;
  static const double kitTopBarFocusRadius = 4;
  static const Duration kitTopBarTabAnimation = Duration(milliseconds: 280);
  static const double homeCategoriesMenuOffsetY = 4;
  static const double homeCategoriesMenuRadius = 8;
  static const double homeCategoriesMenuRowPadH = 16;
  static const double homeCategoriesMenuRowPadV = 10;
  static const double homeCategoriesMenuFontSize = 14;
  static double get kitTopBarTwoRowHeight =>
      homeTopBarHeight + kitTopBarStatusRowTopGap + kitTopBarStatusRowHeight;

  /// Leading inset for shell top-bar menu rows (matches [KitChromeTopBar]).
  static double shellTopBarMenuLeadingInset(BuildContext context) {
    if (usesCompactNavDrawer(context)) {
      return compactMenuLeadingInset(context);
    }
    return bodyHorizontalPadding + homeTopBarMenuLeadingInset;
  }

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

  /// Browse / details TMDB logo cap on Android TV (landscape 720p).
  static const double heroLogoMaxHeightTv = 56;
  static const double heroTitleSlotHeightTv = 64;
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

  /// Extra inset reserved above the bleed rail for hero text.
  static const double homePageBottomSectionTopPadding = 8;

  /// Extra backdrop under the hero so the first bleed row can sit on-image.
  /// Packs may override per hero via `bleedDownOffset`.
  static const double homePageBottomSectionDownOffset = 100;
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

  /// [DetailsUpcomingNotice] + bottom gap in the cinematic hero text column.
  /// Keep in sync with notice padding/typography in play_row.dart.
  static const double heroUpcomingNoticeReserveDesktop = 76;
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
  static const EdgeInsets playerSidePanelPadding = EdgeInsets.fromLTRB(
    12,
    16,
    12,
    8,
  );

  static const double tabHeaderTopPadding = 16;
  static const double tabHeaderBottomPadding = 12;
  static const double tabHeaderFontSize = 32;

  static const double sectionTopSpacing = 20;

  /// Vertical gap between Home content rows (not hero → first row).
  static const double homeRowSpacing = 24;

  /// Compact leanback catalog spacing (pairs with [posterCardWidthTv]).
  static const double tvHomeRowSpacing = 3;
  static const double tvHomeSectionHorizontalPadding = 0;
  static const double tvHeroHeightFraction = 0.72;
  static const double tvHeroNextRowPeekFraction = 0.10;

  /// Catalog row D-pad focus: keep this fraction of viewport below the row.
  static const double tvKitRowFocusBottomInsetFraction = 0.10;

  /// Settings / vertical menus: keep this fraction of viewport below the
  /// focused control so the next row peeks and ATV overscan does not clip
  /// the last item (flush keepVisibleAtEnd hid the final pack).
  static const double tvSettingsFocusBottomInsetFraction = 0.28;

  /// Media-details body rows (Cast / Trailers / …): keep this fraction of
  /// viewport above the focused row so ↑ does not pin flush to the top edge.
  static const double tvDetailsRowFocusTopInsetFraction = 0.25;

  static const double tvHomeSectionTitleTopCompact = 2;
  static const double tvHomeSectionTitleTop = 10;
  static const double tvHomeSectionHeaderHeight = 11;
  static const double tvHomeSectionBottomGap = 4;
  static const double tvPosterCardRowGap = 4;

  /// Gap between poster cards in hub rails (desktop / non-TV).
  /// ~14 separator + former desktop focus-bleed room (bleed is TV-only now).
  static const double posterCardRowGap = 32;

  /// Catalog poster card widths by shell profile.
  static const double posterCardWidthMobile = 165;
  static const double posterCardWidthDesktop = 190;
  static const double posterCardWidthTv = 70;
  static const double posterCardWideBreakpoint = 900;
  static const double posterCardAspectRatio = 1.5;
  static const double posterCardRadius = 14;
  static const double posterCardRadiusMin = 4;
  static const double posterTitleFontSizeMobile = 13;
  static const double posterTitleFontSizeDesktop = 14;
  static const double posterTitleFontSizeTv = 10;
  static const double cardFocusBorderWidth = 1.5;
  static const double cardFocusBleedExtra = 1;
  static const double continueWatchingCardWidthTv = 120;

  /// Shared control / chip height (Portals, action chips, hero pills).
  static const double controlHeight = 40;
  static const double sideRailWidth = 220;
  static const double emptyShellSideRailWidth = 72;
  static const double sidePanelWidth = 380;
  static const double focusBorderRadius = 12;
  static const double focusIdleScale = 1.04;

  static const double hubCardTitleFontSizeMobile = 13;
  static const double hubCardTitleFontSizeDesktop = 14;
  static const double hubCardTitleFontSizeTv = 9;
  static const double heroCompactRightInsetDesktop = 20;
  static const double heroCompactRightInsetTv = 16;
  static const double heroMinTitleHeightDesktop = 72;
  static const double heroMinTitleHeightTv = 64;
  static const double heroMinHeightTv = 400;
  static const double heroMinHeightDesktop = 320;
  static const double heroMetaGapTv = 14;
  static const double heroMetaGapDesktop = 10;
  static const double heroActionGapTv = 16;
  static const double heroActionGapDesktop = 12;
  static const double heroTitleMetaGapDesktop = 20;
  static const double heroMetaActionsGapDesktop = 16;
  static const double kitScrollBottomGapDesktop = 100;
  static const double shellGridTabletMinWidth = 600;

  static const double sectionTitleFontSize = 20;
  static const double sectionTitleFontSizeMin = 11;
  static const double sectionTitleLetterSpacing = -0.3;
  static const double sectionSubtitleFontSize = 11;
  static const double sectionSubtitleFontSizeMin = 8;

  static const double torrentPanelPaddingDesktop = 16;
  static const double torrentPanelPaddingTv = 14;
  static const double torrentPanelTitleFontSizeDesktop = 16;
  static const double torrentPanelTitleFontSizeTv = 15;
  static const double torrentPanelChipPadHDesktop = 12;
  static const double torrentPanelChipPadHTv = 10;
  static const double torrentPanelChipPadVDesktop = 8;
  static const double torrentPanelChipPadVTv = 6;
  static const double torrentPanelChipFontSizeDesktop = 12;
  static const double torrentPanelChipFontSizeTv = 11;
  static const double torrentPanelMetaIconSizeDesktop = 14;
  static const double torrentPanelMetaIconSizeTv = 13;
  static const double torrentPanelMetaFontSizeDesktop = 11;
  static const double torrentPanelMetaFontSizeTv = 10;
  static const double torrentPanelLeadingIconSizeDesktop = 22;
  static const double torrentPanelLeadingIconSizeTv = 20;
  static const double torrentPanelSectionFontSizeDesktop = 16;
  static const double torrentPanelSectionFontSizeTv = 15;

  // --- Pack chrome defaults (overridable via layout props) ---
  static const double portalsChipHeight = controlHeight;
  static const double portalsChipRadius = 8;
  static const double portalsChipFontSize = 12.5;
  static const double portalsChipIconSize = 16;
  static const double portalsChipChevronSize = 18;
  static const double portalsChipSeatsFontSize = 12;
  static const double portalsChipPadCompact = 10;
  static const double portalsChipPad = 14;
  static const double portalsChipStatusSlot = 14;
  static const double portalsChipGap = 8;
  static const double portalsChipGapTight = 6;
  static const double portalsChipDotSize = 8;
  static const double portalsChipStatusStroke = 1.5;
  static const double portalsChipLabelMaxMin = 48;
  static const double portalsChipLabelMaxMax = 280;
  static const double portalsChipLabelMaxFallback = 160;

  static const double categoryRailWidth = sideRailWidth;
  static const double categoryRailListPadV = 8;
  static const double categoryRailPinSlotWidth = 28;
  static const double categoryRailRowExtent = 46;
  static const double categoryRailRowExtentCompact = 42;
  static const double categoryRailLeftBarWidth = 2.5;
  static const double categoryRailRowPadH = 12;
  static const double categoryRailRowPadHCompact = 10;
  static const double categoryRailRowPadV = 8;
  static const double categoryRailRowPadVCompact = 6;
  static const double categoryRailIconSize = 20;
  static const double categoryRailIconSizeCompact = 18;
  static const double categoryRailItemGap = 12;
  static const double categoryRailItemGapCompact = 10;
  static const double categoryRailFontSize = 14;
  static const double categoryRailFontSizeCompact = 13;
  static const double categoryRailPinRadius = 6;
  static const double categoryRailPinPad = 4;

  static const double hubTopBarItemGap = 8;
  static const double hubTopBarSectionGap = 12;
  static const double hubTopBarTabRadius = 8;
  static const double hubTopBarTabPadH = 10;
  static const double hubTopBarTabPadV = 8;
  static const double hubTopBarTabFontSize = 14;

  static const double topBarActionsHeight = controlHeight;
  static const double topBarActionsGap = 8;
  static const double topBarActionsPadV = 8;
  static const double topBarTitleHeight = 48;
  static const double topBarTitleFontSize = 16;

  static const double actionChipHeight = controlHeight;
  static const double actionChipRadius = 20;
  static const double actionChipMaxWidth = 220;
  static const double actionChipPadH = 12;
  static const double actionChipPadV = 6;
  static const double actionChipFontSize = 11.5;
  static const double actionChipGap = 6;
  static const double actionChipIconSize = 16;

  static const double shellChipRadiusPill = 20;
  static const double shellChipRadius = 8;
  static const double shellChipFontSize = 12.5;
  static const double shellChipIconSize = 14;
  static const double shellChipGap = 6;
  static const double shellChipGapTight = 4;

  static const double widgetShelfHeight = 36;
  static const double widgetShelfRadius = 8;
  static const double widgetShelfFontSize = 12.5;
  static const double widgetShelfIconSize = 16;
  static const double widgetShelfGap = 14;

  static const double viewButtonHeight = 36;
  static const double viewButtonIconSize = 18;
  static const double viewButtonGap = 16;

  static const double eventSearchCollapsed = controlHeight;
  static const double eventSearchExpanded = 260;
  static const double eventSearchFontSize = 13;
  static const double eventSearchIconSize = 20;
  static const double eventSearchClearIconSize = 18;

  static const double favStarIconSize = 14;
  static const double denseListRowExtent = 52;
  static const double scrollerArrowOffset = 8;
  static const double scrollerArrowIconSize = 24;
  static const double filterSheetRadius = 12;
  static const double filterSheetHandleWidth = 40;
  static const double filterSheetHandleHeight = 4;
  static const double sheetHandleWidth = 36;
  static const double sheetHandleHeight = 4;

  static const double emptyFeaturesTitleGapTv = 14;
  static const double emptyFeaturesTitleGapDesktop = 28;
  static const double emptyFeaturesBodyGapTv = 10;
  static const double emptyFeaturesBodyGapDesktop = 14;
  static const double emptyFeaturesCardsGapTv = 20;
  static const double emptyFeaturesCardsGapDesktop = 32;
  static const double emptyFeaturesCardGap = 12;
  static const double emptyFeaturesCardGapCompact = 10;
  static const Duration emptyFeaturesCardAnim = Duration(milliseconds: 140);

  /// TV chrome scale vs desktop poster baseline — derived, not a second magic number.
  static double get tvLayoutScale =>
      posterCardWidthTv / posterCardWidthDesktop;

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
  static const Duration tabStaleLive = Duration(minutes: 10);

  @Deprecated('Use tabStaleLive')
  static const Duration tabStaleIptv = tabStaleLive;
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

/// Host [ShellScope] sets [allow] from shell metrics (`allowCompactNavDrawer`).
class CompactNavDrawerPolicy extends InheritedWidget {
  const CompactNavDrawerPolicy({
    super.key,
    required this.allow,
    required super.child,
  });

  final bool allow;

  static bool? maybeAllow(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<CompactNavDrawerPolicy>()
      ?.allow;

  @override
  bool updateShouldNotify(CompactNavDrawerPolicy oldWidget) =>
      allow != oldWidget.allow;
}
