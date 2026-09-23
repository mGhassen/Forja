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

  /// Leanback density families — do **not** apply [tvChromeScale] to every surface.
  ///
  /// | Family | Rule |
  /// |---|---|
  /// | **Chrome / controls** | [tvChromeScale] — chips, pads, pack lengths, control height |
  /// | **Type** | [tvTypeSize] ladder — never × chromeScale |
  /// | **Film posters** | [posterCardWidthTv] — hand-tuned denser than chrome |
  /// | **Channel logos** | [ChannelCardTokens.widthTv] — hand-tuned logo face |
  /// | **Hero** | [tvHeroScale] — softer than chrome so Featured stays tall |
  /// | **Portals rows** | [PortalListTokens.rowHeightTv] — hand-tuned readable rows |
  /// | **Empty / loading** | type ladder + mild pad scale |
  ///
  /// Sniff: if × scale looks correct but ugly, add a hand `*Tv` token for that family.
  static const double tvChromeScale = 0.62;

  /// Softer than [tvChromeScale] — hero band / title reserve stay readable at 10ft.
  static const double tvHeroScale = 0.80;

  /// Leanback type ladder — separate from spatial [tvChromeScale].
  /// Keep smaller than desktop so type matches dense cards (not 14/16 desktop-ish).
  static const double tvBodyFontSize = 9;
  static const double tvTitleFontSize = 11;
  static const double tvMetaFontSize = 8;

  /// Map a desktop font size onto the leanback ladder.
  static double tvTypeSize(double desktop) {
    if (desktop >= 16) return tvTitleFontSize;
    if (desktop >= 12) return tvBodyFontSize;
    return tvMetaFontSize;
  }

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

  /// Same boost as desktop — TV icons are already chrome-scaled, so this keeps
  /// avatar-to-name proportions matching the desktop rail.
  static const double navRailProfileAvatarScaleTv =
      navRailProfileAvatarScaleDesktop;

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

  /// Leanback body type — same step as category / top-bar / details body.
  static const double navRailLabelFontSizeTv = tvBodyFontSize;

  /// @Deprecated — use [navRailLabelFontSizeTv].
  static const double navRailLabelFontSizeTvMin = tvBodyFontSize;

  /// Line-height multiplier for rail labels — slot must match or glyphs clip.
  static const double navRailLabelLineHeight = 1.2;
  static const double navRailItemSpacing = 28;
  static const double navRailItemSpacingTv = navRailItemSpacing * tvChromeScale;
  static const double navRailItemSpacingMin = 2;
  static const double navRailLogoGapDesktop = 20;
  static const double navRailLogoGapTv = navRailLogoGapDesktop * tvChromeScale;
  static const double navRailBottomPaddingDesktop = 16;
  static const double navRailBottomPaddingTv =
      navRailBottomPaddingDesktop * tvChromeScale;
  static const double navRailTopPaddingTv = 8 * tvChromeScale;
  static const double navRailProfileSpacingTv = 4 * tvChromeScale;
  static const double navRailNavPadVTv = 4 * tvChromeScale;
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
  /// Hold a nav tab this long to remount hubs and reload navbar config.
  static const Duration navCompleteReloadHold = Duration(seconds: 4);
  /// Start the in-icon water fill while holding toward [navCompleteReloadHold].
  static const Duration navCompleteReloadHoldCue = Duration(milliseconds: 600);
  /// Empty (unfilled) icon opacity during the hold fill.
  static const double navCompleteReloadHoldIconDim = 0.4;
  /// Wave crest height as a fraction of icon size.
  static const double navCompleteReloadHoldWaveAmplitude = 0.08;
  /// Horizontal wave cycles across the icon width.
  static const double navCompleteReloadHoldWaveCycles = 1.6;
  /// Looping wave drift period.
  static const Duration navCompleteReloadHoldWavePeriod = Duration(
    milliseconds: 900,
  );
  static const Duration navRailIconScaleAnimation = Duration(milliseconds: 520);
  static const Duration navRailLabelLetterInterval = Duration(milliseconds: 72);
  static const Duration navRailLabelRevealAnimation = Duration(
    milliseconds: 520,
  );

  /// Pack-update badge on profile / Settings nav chrome.
  static const double packUpdateBadgeSize = 22;
  static const double packUpdateBadgeSizeTv = 20;
  static const double packUpdateBadgeSizeBottomNav = 18;
  static const double packUpdateBadgeCornerInset = 12;
  static const double packUpdateFlyoutIconSize = 16;
  static const double packUpdateFlyoutWidth = 168;
  static const double packUpdateFlyoutPadH = 14;
  static const double packUpdateFlyoutPadV = 12;
  static const double packUpdateFlyoutGap = 8;
  static const double packUpdateFlyoutRadius = 12;
  static const double packUpdateFlyoutTitleSize = 12;
  static const double packUpdateFlyoutMetaSize = 11;
  static const double packUpdateFlyoutMetaGap = 6;
  static const double packUpdateFlyoutBlur = 28;
  static const double packUpdateFlyoutOffset = 10;
  static const double packUpdateFlyoutSlide = 8;
  static const double packUpdateHeartbeatScaleMin = 0.88;
  static const double packUpdateHeartbeatScaleMax = 1.08;
  static const double packUpdateGlyphScale = 0.62;
  static const double packUpdateSunScale = 0.92;
  static const double packUpdateBangFontScale = 0.55;
  static const double packUpdateBangOffsetX = 0.08;
  static const double packUpdateBangOffsetY = 0.12;
  static const double packUpdateGlowBlurScale = 0.35;
  static const double packUpdateGlowAlpha = 0.45;
  static const double packUpdateGlowSpread = 0.5;
  static const double packUpdateSunInkAlpha = 0.88;
  static const Duration packUpdateHeartbeat = Duration(milliseconds: 1100);
  static const Duration packUpdateFlyoutAnim = Duration(milliseconds: 180);

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

  /// Leanback VF / provider rail — denser than desktop, still logo-readable.
  static const double shellProviderTileWidthTv = 68;
  static const double shellProviderTileHeightTv = 38;
  static const double shellProviderTileRadiusTv = 5;
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
  static const double shellProviderRailGapTv = 6;
  static const double shellProviderRailPadH = 12;
  static const double shellProviderRailPadHTv = 8;
  static const double shellProviderRailPadV = 14;
  static const double shellProviderRailPadVTv = 8;
  static const double shellProviderRailWidth =
      shellProviderTileWidth + shellProviderRailPadH * 2;
  static const double shellProviderRailWidthTv =
      shellProviderTileWidthTv + shellProviderRailPadHTv * 2;
  static const double shellProviderRailInset = 10;
  static const double shellProviderRailInsetTv = 6;
  static const double shellProviderRailRadius = 18;
  static const double shellProviderRailRadiusTv = 12;

  /// Selected-provider mark before Films — rectangle (wordmark-friendly).
  static const double shellProviderTopBarIconWidth = 88;
  static const double shellProviderTopBarIconHeight = 40;

  /// Leanback — denser than desktop (matches [tvChromeScale]).
  static const double shellProviderTopBarIconWidthTv = 64;
  static const double shellProviderTopBarIconHeightTv = 30;

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
  static const double homeMenuRowHeightTv = homeMenuRowHeight * tvChromeScale;
  static const double homeTopBarHeight =
      shellHeaderTopPadding +
      homeMenuRowHeight +
      shellCategoryUnderlineGap +
      shellNavUnderlineHeight;
  static const double homeTopBarHeightTv =
      shellHeaderTopPadding +
      homeMenuRowHeightTv +
      shellCategoryUnderlineGap +
      shellNavUnderlineHeight;

  /// Extra inset before the Films tab in [HomeTopBar].
  static const double homeTopBarMenuLeadingInset = 28;
  static const double homeTopBarMenuLeadingInsetTv =
      homeTopBarMenuLeadingInset * tvChromeScale;

  /// Hoisted `kit.menu` → `kit.tabs` gap in [KitTopBar].
  static const double kitTopBarStatusRowTopGap = 10;
  static const double kitTopBarStatusRowTopGapTv =
      kitTopBarStatusRowTopGap * tvChromeScale;
  static const double kitTopBarStatusRowHeight = 42;
  static const double kitTopBarStatusRowHeightTv =
      kitTopBarStatusRowHeight * tvChromeScale;
  static const double kitTopBarHideSlideDistance = 56;
  static const double kitTopBarTabGapCompact = 20;
  static const double kitTopBarTabGapWide = 36;
  static const double kitTopBarTabGapTv = kitTopBarTabGapWide * tvChromeScale;
  static const double kitTopBarTabGapCompactMaxWidth = 560;
  static const double kitTopBarTabFontSize = 17;
  static const double kitTopBarTabFontSizeTv = tvTitleFontSize;
  static const double kitTopBarChevronSize = 18;
  static const double kitTopBarChevronSizeTv =
      kitTopBarChevronSize * tvChromeScale;
  static const double kitTopBarIconGap = 6;
  static const double kitTopBarChevronGap = 4;
  static const double kitTopBarUnderlineHoverWidth = 28;
  static const double kitTopBarUnderlineSelectedExtra = 4;
  static const double kitTopBarFocusRadius = 4;
  static const Duration kitTopBarTabAnimation = Duration(milliseconds: 280);
  static const double homeCategoriesMenuOffsetY = 4;
  static const double homeCategoriesMenuRadius = 8;
  static const double homeCategoriesMenuRowPadH = 16;
  static const double homeCategoriesMenuRowPadHTv =
      homeCategoriesMenuRowPadH * tvChromeScale;
  static const double homeCategoriesMenuRowPadV = 10;
  static const double homeCategoriesMenuRowPadVTv =
      homeCategoriesMenuRowPadV * tvChromeScale;
  static const double homeCategoriesMenuFontSize = 14;
  static const double homeCategoriesMenuFontSizeTv = tvBodyFontSize;
  static double get kitTopBarTwoRowHeight =>
      homeTopBarHeight + kitTopBarStatusRowTopGap + kitTopBarStatusRowHeight;
  static double get kitTopBarTwoRowHeightTv =>
      homeTopBarHeightTv +
      kitTopBarStatusRowTopGapTv +
      kitTopBarStatusRowHeightTv;

  /// Leading inset for shell top-bar menu rows (matches [KitChromeTopBar]).
  /// Callers on TV should pass [homeTopBarMenuLeadingInsetTv] via kit chrome.
  static double shellTopBarMenuLeadingInset(BuildContext context) {
    if (usesCompactNavDrawer(context)) {
      return compactMenuLeadingInset(context);
    }
    return bodyHorizontalPadding + homeTopBarMenuLeadingInset;
  }

  /// Home Categories popup: visible rows before scrolling.
  static const double homeCategoriesMenuRowHeight = 38;
  static const double homeCategoriesMenuRowHeightTv =
      homeCategoriesMenuRowHeight * tvChromeScale;
  static const int homeCategoriesMenuMaxVisibleRows = 8;
  static double get homeCategoriesMenuMaxHeight =>
      homeCategoriesMenuRowHeight * homeCategoriesMenuMaxVisibleRows;
  static double get homeCategoriesMenuMaxHeightTv =>
      homeCategoriesMenuRowHeightTv * homeCategoriesMenuMaxVisibleRows;
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

  /// Desktop hero text column width as a fraction of screen width (capped by
  /// [heroTextColumnWidthDesktop]). Not [heroImageStartFraction] — that is
  /// only where the backdrop image strip begins.
  static const double heroTextWidthFraction = 0.34;

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

  /// Spotlight auto-advance dwell before the next slide.
  static const Duration heroAutoAdvanceDuration = Duration(seconds: 8);

  /// PageView transition when auto-advance / stepFilm animates.
  static const Duration heroAutoAdvancePageDuration = Duration(milliseconds: 1000);

  /// Vertical step-indicator stadium (active pill width × height).
  static const double heroStepIndicatorActiveWidth = 18;
  static const double heroStepIndicatorSize = 6;
  static const double heroStepIndicatorRadius = 3;
  static const double heroStepIndicatorGap = 4;
  static const double heroStepIndicatorTrackAlpha = 0.35;
  static const double heroStepIndicatorFillAlpha = 0.95;
  /// Pause glyph when View details / pin holds auto-advance.
  static const double heroStepIndicatorPauseSize = 14;

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
  static const EdgeInsets playerSidePanelPaddingTv = EdgeInsets.fromLTRB(
    8,
    8,
    8,
    6,
  );

  /// Player overlay Sources / Episodes / torrent file panel width (wide screens).
  static const double playerSidePanelWidth = 480;
  static const double playerSidePanelWidthTv =
      playerSidePanelWidth * tvChromeScale;

  /// Filters dock left of Sources — desktop preferred max; TV chrome-scaled.
  static const double sourcesFilterPanelWidth = 420;
  static const double sourcesFilterPanelWidthTv =
      sourcesFilterPanelWidth * tvChromeScale;
  static const double sourcesFilterPanelSoftMin = 280;
  static const double sourcesFilterPanelSoftMinTv =
      sourcesFilterPanelSoftMin * tvChromeScale;
  static const EdgeInsets sourcesFilterPanelPadding = EdgeInsets.fromLTRB(
    20,
    8,
    12,
    16,
  );
  static const EdgeInsets sourcesFilterPanelPaddingTv = EdgeInsets.fromLTRB(
    12,
    4,
    8,
    10,
  );

  /// Below this width the player side panel goes nearly full-bleed.
  static const double playerSidePanelNarrowMaxWidth = 700;

  /// Player transport / top chrome (Exo + MediaKit TV row).
  static const double playerChromeBtnSize = 38;
  static const double playerChromeBtnSizeTv = playerChromeBtnSize * tvChromeScale;
  static const double playerChromeIconSize = 20;
  static const double playerChromeIconSizeTv =
      playerChromeIconSize * tvChromeScale;
  static const double playerChromeTopBtnSize = 44;
  static const double playerChromeTopBtnSizeTv =
      playerChromeTopBtnSize * tvChromeScale;
  /// IPTV / live transport round icons (non-play).
  static const double playerChromeRoundBtnSize = playerChromeTopBtnSize;
  static const double playerChromeRoundBtnSizeTv = playerChromeTopBtnSizeTv;
  static const double playerChromeRoundIconSize = 22;
  static const double playerChromeRoundIconSizeTv =
      playerChromeRoundIconSize * tvChromeScale;
  /// IPTV / live primary play/pause circle (larger than round peers).
  static const double playerChromePlayBtnSize = 56;
  static const double playerChromePlayBtnSizeTv =
      playerChromePlayBtnSize * tvChromeScale;
  static const double playerChromePlayIconSize = 32;
  static const double playerChromePlayIconSizeTv =
      playerChromePlayIconSize * tvChromeScale;
  static const double playerChromeTitleFontSize = 16;
  static const double playerChromeTitleFontSizeTv = tvTitleFontSize;
  static const double playerChromeHeroTitleFontSize = 18;
  static const double playerChromeHeroTitleFontSizeTv = tvTitleFontSize;
  static const double playerChromeMetaFontSize = 12;
  static const double playerChromeMetaFontSizeTv = tvBodyFontSize;
  static const double playerChromeTimeFontSize = 11;
  static const double playerChromeTimeFontSizeTv = tvMetaFontSize;
  static const double playerChromeStatusFontSize = 13;
  static const double playerChromeStatusFontSizeTv = tvBodyFontSize;
  /// IPTV live top-bar channel mark + progress-row logo.
  static const double playerChromeLogoSize = 36;
  static const double playerChromeLogoSizeTv =
      playerChromeLogoSize * tvChromeScale;
  static const double playerChromeProgressLogoSize = 72;
  static const double playerChromeProgressLogoSizeTv =
      playerChromeProgressLogoSize * tvChromeScale;
  static const double playerChromeProgressLogoSizeCompact = 56;
  static const double playerChromeProgressLogoSizeCompactTv =
      playerChromeProgressLogoSizeCompact * tvChromeScale;

  /// Paused VOD hero title logo (left of player chrome).
  static const double playerPausedHeroLogoMaxHeight = 96;
  static const double playerPausedHeroLogoMaxHeightTv =
      playerPausedHeroLogoMaxHeight * tvChromeScale;
  static const double playerPausedHeroMaxWidth = 520;
  static const double playerPausedHeroMaxWidthTv =
      playerPausedHeroMaxWidth * tvChromeScale;
  static const EdgeInsets playerPausedHeroPadding =
      EdgeInsets.fromLTRB(20, 0, 20, 0);
  static const EdgeInsets playerPausedHeroPaddingTv =
      EdgeInsets.fromLTRB(12, 0, 12, 0);

  /// In-player CHECKING SOURCES / buffering status (right-center, no card).
  static const double playerStatusEdgeInset = 20;
  static const double playerStatusEdgeInsetTv =
      playerStatusEdgeInset * tvChromeScale;
  static const double playerStatusColumnWidth = 260;
  static const double playerStatusColumnWidthTv =
      playerStatusColumnWidth * tvChromeScale;
  static const double playerStatusHeaderFontSize = 11;
  static const double playerStatusHeaderFontSizeTv = tvMetaFontSize;
  static const double playerStatusLabelFontSize = 17;
  static const double playerStatusLabelFontSizeTv = tvTitleFontSize;
  static const double playerStatusLabelFontSizeCompact = 13;
  static const double playerStatusLabelFontSizeCompactTv = tvBodyFontSize;
  static const double playerStatusMetaFontSize = 12;
  static const double playerStatusMetaFontSizeTv = tvMetaFontSize;
  static const double playerStatusSpinnerSize = 16;
  static const double playerStatusSpinnerSizeTv =
      playerStatusSpinnerSize * tvChromeScale;
  static const double playerStatusSpinnerStroke = 2.0;
  static const double playerStatusSpinnerStrokeTv = 1.6;
  static const double playerStatusIconSize = 16;
  static const double playerStatusIconSizeTv =
      playerStatusIconSize * tvChromeScale;
  static const double playerStatusProgressHeight = 2.5;
  static const double playerStatusProgressHeightTv = 2;
  static const double playerStatusProgressWidth = 120;
  static const double playerStatusProgressWidthTv =
      playerStatusProgressWidth * tvChromeScale;
  static const double playerStatusRouletteSlotHeight = 56;
  static const double playerStatusRouletteSlotHeightTv =
      playerStatusRouletteSlotHeight * tvChromeScale;
  static const double playerStatusHeaderGap = 14;
  static const double playerStatusHeaderGapTv =
      playerStatusHeaderGap * tvChromeScale;
  static const double playerStatusProgressGap = 10;
  static const double playerStatusProgressGapTv =
      playerStatusProgressGap * tvChromeScale;
  static const double playerStatusMetaGap = 8;
  static const double playerStatusMetaGapTv =
      playerStatusMetaGap * tvChromeScale;

  /// Seek / scrubber hit strip + track + thumb (Exo / MediaKit / trailer / IPTV VOD).
  static const double playerChromeSeekHitHeight = 32;
  static const double playerChromeSeekHitHeightTv =
      playerChromeSeekHitHeight * tvChromeScale;
  static const double playerChromeSeekHitHeightCompact = 28;
  static const double playerChromeSeekHitHeightCompactTv =
      playerChromeSeekHitHeightCompact * tvChromeScale;
  static const double playerChromeSeekTrackHeight = 3.5;
  static const double playerChromeSeekTrackHeightTv =
      playerChromeSeekTrackHeight * tvChromeScale;
  /// Drag / armed scrub — thicker than idle.
  static const double playerChromeSeekTrackHeightActive = 6;
  static const double playerChromeSeekTrackHeightActiveTv =
      playerChromeSeekTrackHeightActive * tvChromeScale;
  /// TV D-pad focus highlight — between idle and drag.
  static const double playerChromeSeekTrackHeightFocused = 4;
  static const double playerChromeSeekTrackHeightFocusedTv =
      playerChromeSeekTrackHeightFocused * tvChromeScale;
  static const double playerChromeSeekThumbRadius = 5.5;
  static const double playerChromeSeekThumbRadiusTv =
      playerChromeSeekThumbRadius * tvChromeScale;
  static const double playerChromeSeekThumbRadiusActive = 8;
  static const double playerChromeSeekThumbRadiusActiveTv =
      playerChromeSeekThumbRadiusActive * tvChromeScale;

  /// Catalog / IPTV top chrome — tight under the window / title strip.
  static const double tabHeaderTopPadding = 8;
  static const double tabHeaderBottomPadding = 12;
  static const double tabHeaderFontSize = 32;

  static const double sectionTopSpacing = 20;

  /// Vertical gap between Home content rows (not hero → first row).
  static const double homeRowSpacing = 24;

  /// Compact leanback catalog spacing (pairs with [posterCardWidthTv]).
  static const double tvHomeRowSpacing = homeRowSpacing * tvChromeScale;
  static const double tvHomeSectionHorizontalPadding =
      homeSectionHorizontalPadding * tvChromeScale;
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

  static const double tvHomeSectionTitleTopCompact = 2 * tvChromeScale;
  static const double tvHomeSectionTitleTop = 10 * tvChromeScale;
  static const double tvHomeSectionHeaderHeight = tvTitleFontSize;
  static const double tvHomeSectionBottomGap = 8 * tvChromeScale;

  /// Gap between poster cards in hub rails (desktop / non-TV).
  /// ~14 separator + former desktop focus-bleed room (bleed is TV-only now).
  static const double posterCardRowGap = 32;
  static const double tvPosterCardRowGap = posterCardRowGap * tvChromeScale;

  /// Catalog poster card widths by shell profile.
  static const double posterCardWidthMobile = 165;
  static const double posterCardWidthDesktop = 190;

  /// TV film posters — **film family** hand-tuned (denser than × [tvChromeScale]).
  static const double posterCardWidthTv = 100;

  /// IPTV / live channel tiles — **channel family** hand-tuned logo face
  /// (keep in sync with [ChannelCardTokens.widthTv]).
  static const double channelCardWidthTv = 110;

  /// Leanback chrome — [tvChromeScale] (not film poster width).
  static const double navRailWidthTv = navRailWidth * tvChromeScale;
  static const double navRailLogoWidthTv = navRailLogoWidth * tvChromeScale;
  static const double navRailLogoHeightTv = navRailLogoWidthTv * 160 / 370;

  /// Leanback hero chrome — chrome scale (hero band height stays on [tvHeroScale]).
  static const double heroLogoMaxHeightTv =
      heroLogoMaxHeightDesktop * tvChromeScale;
  static const double heroTitleSlotHeightTv =
      heroTitleSlotHeightDesktop * tvChromeScale;

  /// Fallback text title (no logo) — hand ladder, not × chrome (10ft readable).
  static const double heroFallbackTitleMin = 20;
  static const double heroFallbackTitleMinTv = tvTitleFontSize;
  static const double heroFallbackTitlePreferredMax = 40;
  static const double heroFallbackTitlePreferredMaxTv = 16;

  static const double posterCardWideBreakpoint = 900;
  static const double posterCardAspectRatio = 1.5;
  static const double posterCardRadius = 14;
  static const double posterCardRadiusMin = 4;
  static const double posterTitleFontSizeMobile = 13;
  static const double posterTitleFontSizeDesktop = 14;
  static const double posterTitleFontSizeTv = tvBodyFontSize;

  /// Star + score chip on film poster corners (type family on TV — not × chrome).
  static const double posterRatingFontSize = 11;
  static const double posterRatingFontSizeTv = tvMetaFontSize;
  static const double posterRatingIconSize = 12;
  static const double posterRatingIconSizeTv = 7;
  static const double posterRatingPadH = 7;
  static const double posterRatingPadV = 4;
  static const double posterRatingPadHTv = 3;
  static const double posterRatingPadVTv = 1;
  static const double posterRatingRadius = 8;
  static const double posterRatingRadiusTv = 3;
  static const double posterRatingGap = 3;
  static const double posterRatingGapTv = 1;

  /// Text corner badge on posters (NOW / REMAKE / …).
  static const double posterBadgeFontSize = 9;
  static const double posterBadgeFontSizeTv = tvMetaFontSize;
  static const double posterBadgePadH = 6;
  static const double posterBadgePadHTv = 4;
  static const double posterBadgePadV = 2;
  static const double posterBadgePadVTv = 1;
  static const double posterBadgeRadius = 4;
  static const double posterBadgeRadiusTv = 3;

  /// Outlined rank digit behind Popular / top-N posters (outside focus chrome).
  static const double posterRankFontSize = 120;
  static const double posterRankStrokeWidth = 2;
  static const double posterRankLetterSpacing = -8;
  static const double posterRankLineHeight = 0.85;
  static const double posterRankStrokeAlpha = 0.1;

  static const double cardFocusBorderWidth = 1.5;
  static const double cardFocusBleedExtra = 1;
  static const double continueWatchingCardWidthTv =
      shellContinueWatchingCardWidthDesktop * tvChromeScale;

  /// Shared control / chip height (Portals, action chips, hero pills).
  static const double controlHeight = 40;
  static const double controlHeightTv = controlHeight * tvChromeScale;
  static const double sideRailWidth = 220;
  static const double sideRailWidthTv = sideRailWidth * tvChromeScale;
  static const double emptyShellSideRailWidth = 72;
  static const double sidePanelWidth = 380;
  /// Leanback Portals / side rail — chrome family.
  static const double sidePanelWidthTv = sidePanelWidth * tvChromeScale;
  /// Docked side panel vs modal sheet — same gate as [SidePanelOverlay].
  /// Android TV always docks even when the layout strip is under this width.
  static const double sidePanelWideBreakpoint = 900;
  static const double focusBorderRadius = 12;
  static const double focusIdleScale = 1.04;

  static const double hubCardTitleFontSizeMobile = 13;
  static const double hubCardTitleFontSizeDesktop = 14;
  static const double hubCardTitleFontSizeTv = tvBodyFontSize;
  static const double heroCompactRightInsetDesktop = 20;
  static const double heroCompactRightInsetTv =
      heroCompactRightInsetDesktop * tvHeroScale;
  static const double heroMinTitleHeightDesktop = 72;
  static const double heroMinTitleHeightTv =
      heroMinTitleHeightDesktop * tvHeroScale;
  static const double heroMinHeightDesktop = 320;

  /// TV min — hero family ([tvHeroScale]), not full chrome crush.
  static const double heroMinHeightTv = heroMinHeightDesktop * tvHeroScale;
  static const double heroMetaGapDesktop = 10;
  static const double heroMetaGapTv = heroMetaGapDesktop * tvHeroScale;
  static const double heroActionGapDesktop = 12;
  static const double heroActionGapTv = heroActionGapDesktop * tvHeroScale;
  static const double heroTitleMetaGapDesktop = 20;
  static const double heroMetaActionsGapDesktop = 16;
  static const double kitScrollBottomGapDesktop = 100;
  static const double shellGridTabletMinWidth = 600;

  static const double sectionTitleFontSize = 20;
  static const double sectionTitleFontSizeMin = tvTitleFontSize;
  static const double sectionTitleLetterSpacing = -0.3;
  static const double sectionSubtitleFontSize = 11;
  static const double sectionSubtitleFontSizeMin = tvMetaFontSize;

  static const double torrentPanelPaddingDesktop = 16;
  /// Chrome family — matches player side-panel inset weight.
  static const double torrentPanelPaddingTv =
      torrentPanelPaddingDesktop * tvChromeScale;
  static const double torrentPanelTitleFontSizeDesktop = 16;
  static const double torrentPanelTitleFontSizeTv = tvTitleFontSize;
  /// Stream / provider row card title (smaller than panel section title).
  static const double torrentPanelRowTitleFontSizeDesktop = 13;
  static const double torrentPanelRowTitleFontSizeTv = tvBodyFontSize;
  static const double torrentPanelRowPadHDesktop = 12;
  static const double torrentPanelRowPadHTv =
      torrentPanelRowPadHDesktop * tvChromeScale;
  static const double torrentPanelRowPadVDesktop = 10;
  static const double torrentPanelRowPadVTv =
      torrentPanelRowPadVDesktop * tvChromeScale;
  static const double torrentPanelRowBadgePadHDesktop = 7;
  static const double torrentPanelRowBadgePadHTv =
      torrentPanelRowBadgePadHDesktop * tvChromeScale;
  static const double torrentPanelRowBadgePadVDesktop = 3;
  static const double torrentPanelRowBadgePadVTv =
      torrentPanelRowBadgePadVDesktop * tvChromeScale;
  static const double torrentPanelRowBadgeRadiusDesktop = 6;
  static const double torrentPanelRowBadgeRadiusTv =
      torrentPanelRowBadgeRadiusDesktop * tvChromeScale;
  static const double torrentPanelChipPadHDesktop = 12;
  /// Hand-tuned denser than desktop × chrome — match action chips / search.
  static const double torrentPanelChipPadHTv = actionChipPadHTv;
  static const double torrentPanelChipPadVDesktop = 8;
  /// Leanback Sources provider chips — taller than chrome-crush so D-pad pills
  /// stay readable (was 3; text sat on the border).
  static const double torrentPanelChipPadVTv = 6;
  static const double torrentPanelChipFontSizeDesktop = 12;
  /// Dense strip type — same ladder rung as action chips (not body).
  static const double torrentPanelChipFontSizeTv = tvMetaFontSize;
  static const double torrentPanelMetaIconSizeDesktop = 14;
  static const double torrentPanelMetaIconSizeTv = actionChipIconSizeTv;
  static const double torrentPanelMetaFontSizeDesktop = 11;
  static const double torrentPanelMetaFontSizeTv = tvMetaFontSize;
  static const double torrentPanelLeadingIconSizeDesktop = 22;
  static const double torrentPanelLeadingIconSizeTv =
      torrentPanelLeadingIconSizeDesktop * tvChromeScale;
  static const double torrentPanelSectionFontSizeDesktop = 16;
  static const double torrentPanelSectionFontSizeTv = tvTitleFontSize;

  /// Kind-tab underline pad under Forja / Torrents / … labels.
  static const double torrentPanelKindTabPadHDesktop = 14;
  static const double torrentPanelKindTabPadHTv =
      torrentPanelKindTabPadHDesktop * tvChromeScale;
  static const double torrentPanelKindTabPadBottomDesktop = 9;
  static const double torrentPanelKindTabPadBottomTv =
      torrentPanelKindTabPadBottomDesktop * tvChromeScale;
  static const double torrentPanelKindTabIconGapDesktop = 7;
  static const double torrentPanelKindTabIconGapTv =
      torrentPanelKindTabIconGapDesktop * tvChromeScale;
  static const double torrentPanelChromeGapDesktop = 8;
  static const double torrentPanelChromeGapTv =
      torrentPanelChromeGapDesktop * tvChromeScale;

  /// Air between kind-tab underline and provider chips (All / Videasy / …).
  static const double torrentPanelProvidersTopGapDesktop = 12;
  static const double torrentPanelProvidersTopGapTv =
      torrentPanelProvidersTopGapDesktop * tvChromeScale;

  /// Air between search/filter toolbar and the stream list.
  static const double torrentPanelListTopGapDesktop = 12;
  static const double torrentPanelListTopGapTv =
      torrentPanelListTopGapDesktop * tvChromeScale;

  /// Sources panel search field (details + player) — same control band as
  /// Episodes search / top-bar chips (`controlHeight`).
  static const double torrentPanelSearchHeight = controlHeight;
  static const double torrentPanelSearchHeightTv = controlHeightTv;
  static const double torrentPanelSearchFontSize = 13;
  static const double torrentPanelSearchFontSizeTv = tvBodyFontSize;
  static const double torrentPanelSearchIconSize = 18;
  static const double torrentPanelSearchIconSizeTv = actionChipIconSizeTv;
  static const double torrentPanelSearchPadH = 12;
  static const double torrentPanelSearchPadHTv =
      torrentPanelSearchPadH * tvChromeScale;
  /// Vertical pad inside the fixed [torrentPanelSearchHeight] face.
  /// Episodes search still uses this; Sources search uses zero pad + fixed face.
  static const double torrentPanelSearchPadV = 10;
  /// Tighter than desktop × chrome — field must fit leanback type without clipping.
  static const double torrentPanelSearchPadVTv = 4;
  static const double torrentPanelSearchRadius = 10;
  static const double torrentPanelSearchRadiusTv =
      torrentPanelSearchRadius * tvChromeScale;
  static const double torrentPanelSearchGap = 8;
  static const double torrentPanelSearchGapTv =
      torrentPanelSearchGap * tvChromeScale;
  static const double torrentPanelFilterIconSize = 18;
  static const double torrentPanelFilterIconSizeTv = actionChipIconSizeTv;
  /// Tune button beside Search — same height so the toolbar row stays aligned.
  static const double torrentPanelFilterButtonHeight = torrentPanelSearchHeight;
  static const double torrentPanelFilterButtonHeightTv =
      torrentPanelSearchHeightTv;

  /// Sources / Providers stream list — estimated row for lazy scroll-into-view
  /// when the tile is not mounted yet (same keep-visible contract as IPTV cats).
  /// Mounted tiles measure themselves; this is only the off-screen jump stride.
  static const double sourcesStreamListSeparator = 6;
  static const double sourcesStreamListRowExtentEstimate = 92;
  static const double sourcesStreamListRowExtentEstimateTv = 78;
  static double sourcesStreamListRowExtentEstimateOf(bool tv) => tv
      ? sourcesStreamListRowExtentEstimateTv
      : sourcesStreamListRowExtentEstimate;
  static double sourcesStreamListStrideOf(bool tv) =>
      sourcesStreamListRowExtentEstimateOf(tv) + sourcesStreamListSeparator;

  // --- Pack chrome defaults (overridable via layout props) ---
  static const double portalsChipHeight = controlHeight;
  static const double portalsChipHeightTv = controlHeightTv;
  static const double portalsChipRadius = 8;
  static const double portalsChipFontSize = 12.5;
  static const double portalsChipFontSizeTv = tvBodyFontSize;
  static const double portalsChipIconSize = 16;
  static const double portalsChipIconSizeTv = 12;
  static const double portalsChipChevronSize = 18;
  static const double portalsChipChevronSizeTv = 14;
  static const double portalsChipSeatsFontSize = 12;
  static const double portalsChipPadCompact = 10;
  static const double portalsChipPad = 14;
  static const double portalsChipPadTv = 8;
  static const double portalsChipStatusSlot = 14;
  static const double portalsChipGap = 8;
  static const double portalsChipGapTight = 6;
  static const double portalsChipDotSize = 8;
  static const double portalsChipStatusStroke = 1.5;
  static const double portalsChipLabelMaxMin = 48;
  static const double portalsChipLabelMaxMax = 280;
  static const double portalsChipLabelMaxFallback = 160;

  static const double categoryRailWidth = sideRailWidth;
  static const double categoryRailWidthTv = sideRailWidthTv;
  static const double categoryRailListPadV = 8;
  static const double categoryRailListPadVTv = 4;
  static const double categoryRailPinSlotWidth = 28;
  static const double categoryRailPinSlotWidthTv = 22;
  static const double categoryRailRowExtent = 46;
  static const double categoryRailRowExtentCompact = 42;
  static const double categoryRailRowExtentTv = 32;
  static const double categoryRailLeftBarWidth = 2.5;
  static const double categoryRailRowPadH = 12;
  static const double categoryRailRowPadHCompact = 10;
  static const double categoryRailRowPadHTv = 8;
  static const double categoryRailRowPadV = 8;
  static const double categoryRailRowPadVCompact = 6;
  static const double categoryRailRowPadVTv = 4;
  static const double categoryRailIconSize = 20;
  static const double categoryRailIconSizeCompact = 18;
  static const double categoryRailIconSizeTv = 14;
  static const double categoryRailItemGap = 12;
  static const double categoryRailItemGapCompact = 10;
  static const double categoryRailItemGapTv = 8;
  static const double categoryRailFontSize = 14;
  static const double categoryRailFontSizeCompact = 13;
  static const double categoryRailFontSizeTv = tvBodyFontSize;
  static const double categoryRailPinRadius = 6;
  static const double categoryRailPinPad = 4;

  static const double hubTopBarItemGap = 8;
  static const double hubTopBarItemGapTv = 6;
  static const double hubTopBarSectionGap = 12;
  static const double hubTopBarSectionGapTv = 8;
  static const double hubTopBarTabRadius = 8;
  static const double hubTopBarTabPadH = 10;
  static const double hubTopBarTabPadHTv = 8;
  static const double hubTopBarTabPadV = 8;
  static const double hubTopBarTabPadVTv = 4;
  static const double hubTopBarTabFontSize = 14;
  static const double hubTopBarTabFontSizeTv = tvBodyFontSize;

  static const double topBarActionsHeight = controlHeight;
  static const double topBarActionsGap = 8;
  static const double topBarActionsPadV = 8;
  static const double topBarTitleHeight = 48;
  static const double topBarTitleFontSize = 16;

  static const double actionChipHeight = controlHeight;
  static const double actionChipHeightTv = controlHeightTv;
  static const double actionChipRadius = 20;
  static const double actionChipRadiusTv = actionChipRadius * tvChromeScale;
  static const double actionChipMaxWidth = 220;
  static const double actionChipPadH = 12;
  static const double actionChipPadHTv = 8;
  static const double actionChipPadV = 6;
  static const double actionChipPadVTv = actionChipPadV * tvChromeScale;
  static const double actionChipFontSize = 11.5;
  static const double actionChipFontSizeTv = tvMetaFontSize;
  static const double actionChipGap = 6;
  static const double actionChipGapTv = actionChipGap * tvChromeScale;
  static const double actionChipIconSize = 16;
  static const double actionChipIconSizeTv = 12;

  static const double shellChipRadiusPill = 20;
  static const double shellChipRadiusPillTv =
      shellChipRadiusPill * tvChromeScale;
  static const double shellChipRadius = 8;
  static const double shellChipRadiusTv = shellChipRadius * tvChromeScale;
  static const double shellChipFontSize = 12.5;
  static const double shellChipFontSizeTv = tvBodyFontSize;
  static const double shellChipIconSize = 14;
  static const double shellChipIconSizeTv = actionChipIconSizeTv;
  static const double shellChipPadH = 14;
  static const double shellChipPadHTv = shellChipPadH * tvChromeScale;
  static const double shellChipPadV = 8;
  static const double shellChipPadVTv = shellChipPadV * tvChromeScale;
  static const double shellChipGap = 6;
  static const double shellChipGapTv = shellChipGap * tvChromeScale;
  static const double shellChipGapTight = 4;
  static const double shellChipGapTightTv = shellChipGapTight * tvChromeScale;

  static const double denseListTopPad = 4;
  static const double denseListSeparator = 1;
  static const double eventDenseFontSize = 14;
  static const double eventDenseFontSizeTv = tvTitleFontSize;
  static const double eventDenseMetaFontSize = 12;
  static const double eventDenseMetaFontSizeTv = tvBodyFontSize;
  /// Tight line box so title+meta fit [denseListRowExtent] (font metrics alone overflow).
  static const double eventDenseLineHeight = 1.15;
  static const double eventDenseMetaGap = 2;
  static const double eventDenseMetaGapTv = eventDenseMetaGap * tvChromeScale;
  static const double eventDenseIconSize = 20;
  static const double eventDenseIconSizeTv = actionChipIconSizeTv;
  static const double eventDensePadH = 12;
  static const double eventDensePadHTv = eventDensePadH * tvChromeScale;
  static const double eventDensePadV = 10;
  static const double eventDensePadVTv = eventDensePadV * tvChromeScale;
  static const double eventDenseLiveDot = 8;
  static const double eventDenseLiveDotTv = eventDenseLiveDot * tvChromeScale;

  /// Fixed dense-list row height — derived from [EventDenseTile] pad + text stack.
  /// Do **not** chrome-scale desktop → TV: leanback type uses [tvTitleFontSize] /
  /// [tvBodyFontSize], not [tvChromeScale].
  /// +2 slack covers TextPainter / platform font metrics beyond fontSize×height
  /// (Android Roboto overflowed by 1px with +1).
  static const double denseListRowExtent = eventDensePadV * 2 +
      eventDenseFontSize * eventDenseLineHeight +
      eventDenseMetaGap +
      eventDenseMetaFontSize * eventDenseLineHeight +
      2;
  static const double denseListRowExtentTv = eventDensePadVTv * 2 +
      eventDenseFontSizeTv * eventDenseLineHeight +
      eventDenseMetaGapTv +
      eventDenseMetaFontSizeTv * eventDenseLineHeight +
      2;
  static double denseListRowExtentOf(bool tv) =>
      tv ? denseListRowExtentTv : denseListRowExtent;
  /// Row + separator stride for scroll-index math ([ListView.separated]).
  static double denseListStrideOf(bool tv) =>
      denseListRowExtentOf(tv) + denseListSeparator;

  static const double widgetShelfHeight = 36;
  static const double widgetShelfHeightTv = 28;
  static const double widgetShelfRadius = 8;
  static const double widgetShelfFontSize = 12.5;
  static const double widgetShelfFontSizeTv = tvBodyFontSize;
  static const double widgetShelfIconSize = 16;
  static const double widgetShelfIconSizeTv = 12;
  static const double widgetShelfGap = 14;
  static const double widgetShelfGapTv = 8;

  static const double viewButtonHeight = 36;
  static const double viewButtonHeightTv = 28;
  static const double viewButtonIconSize = 18;
  static const double viewButtonIconSizeTv = 14;
  static const double viewButtonGap = 16;
  static const double viewButtonGapTv = 10;

  /// Accent mood / sport category circles (desktop catalog + Live Sports).
  static const double moodCircleSize = 56;
  static const double moodCircleItemWidth = 80;
  static const double moodCircleGap = 16;
  static const double moodCircleLabelFontSize = 12.5;
  static const double moodCircleLabelGap = 6;
  static const double moodCircleLabelLineHeight = 1.15;
  static const int moodCircleLabelMaxLines = 2;
  static const double moodCircleBottomPad = moodCircleLabelGap;
  static const double moodCircleIconSize = 20;
  static const double moodCircleIconSizeActive = 26;
  /// Label slot taller than 2× line so wrapped titles do not clip neighbors.
  static const double moodCircleLabelSlotHeight = 34;

  /// circle + gap + label slot + bottom pad.
  static const double moodCircleRowHeight =
      moodCircleSize +
      moodCircleLabelGap +
      moodCircleLabelSlotHeight +
      moodCircleBottomPad;

  /// Accent mood circles on TV (leanback catalog rows).
  ///
  /// Hand-tuned denser than desktop × chrome so circles match the leanback
  /// type ladder (body/meta), not leftover mobile chip chrome.
  static const double moodCircleSizeTv = 34;
  static const double moodCircleItemWidthTv = 48;
  static const double moodCircleGapTv = 4;
  static const double moodCircleLabelFontSizeTv = tvMetaFontSize;
  static const double moodCircleLabelGapTv = 4;
  static const double moodCircleLabelLineHeightTv = 1.15;
  static const int moodCircleLabelMaxLinesTv = 2;
  static const double moodCircleBottomPadTv = moodCircleLabelGapTv;
  static const double moodCircleIconSizeTv = 13;
  static const double moodCircleIconSizeActiveTv = 17;
  static const double moodCircleBorderWidth = 1.5;
  static const double moodCircleBorderWidthSelected = 2.5;
  static const double moodCircleBorderWidthTv = 1;
  static const double moodCircleBorderWidthSelectedTv = 1.5;

  /// circle + gap + (lines × size × height) + bottom pad + font-metric slack.
  static const double moodCircleRowHeightTv =
      moodCircleSizeTv +
      moodCircleLabelGapTv +
      (moodCircleLabelMaxLinesTv *
          moodCircleLabelFontSizeTv *
          moodCircleLabelLineHeightTv) +
      moodCircleBottomPadTv +
      2;

  /// Catalog load ticker (IPTV shelf / hub list loading page).
  static const double catalogLoadingTickerMaxWidth = 360;
  static const double catalogLoadingTickerMaxWidthTv =
      catalogLoadingTickerMaxWidth * tvChromeScale;
  static const double catalogLoadingTickerPadH = 28;
  static const double catalogLoadingTickerPadHTv =
      catalogLoadingTickerPadH * tvChromeScale;
  static const double catalogLoadingTickerPadV = 24;
  static const double catalogLoadingTickerPadVTv =
      catalogLoadingTickerPadV * tvChromeScale;
  static const double catalogLoadingTickerGap = 20;
  static const double catalogLoadingTickerGapTv =
      catalogLoadingTickerGap * tvChromeScale;
  static const double catalogLoadingTickerDetailGap = 8;
  static const double catalogLoadingTickerDetailGapTv =
      catalogLoadingTickerDetailGap * tvChromeScale;
  static const double catalogLoadingTickerTitleFontSize = 18;
  static const double catalogLoadingTickerTitleFontSizeTv = tvTitleFontSize;
  static const double catalogLoadingTickerDetailFontSize = 13;
  static const double catalogLoadingTickerDetailFontSizeTv = tvBodyFontSize;
  static const double catalogLoadingTickerSpinner = 36;
  static const double catalogLoadingTickerSpinnerTv =
      catalogLoadingTickerSpinner * tvChromeScale;
  static const double catalogLoadingTickerStroke = 3;
  static const double catalogLoadingTickerStrokeTv =
      catalogLoadingTickerStroke * tvChromeScale;
  static const double catalogLoadingTickerSlotHeight = 160;
  static const double catalogLoadingTickerSlotHeightTv =
      catalogLoadingTickerSlotHeight * tvChromeScale;

  /// Pre-play stream loading page (backdrop + logo + status / Cancel / servers).
  /// Chrome pads × [tvChromeScale]; type uses the leanback ladder.
  static const double streamLoadingStatusStripReserve = 240;
  static const double streamLoadingStatusStripReserveTv =
      streamLoadingStatusStripReserve * tvChromeScale;
  static const double streamLoadingProviderListExtra = 200;
  static const double streamLoadingProviderListExtraTv =
      streamLoadingProviderListExtra * tvChromeScale;
  static const double streamLoadingBottomInset = 48;
  static const double streamLoadingBottomInsetTv =
      streamLoadingBottomInset * tvChromeScale;
  static const double streamLoadingPadH = 24;
  static const double streamLoadingPadHTv =
      streamLoadingPadH * tvChromeScale;
  static const double streamLoadingSpinnerStroke = 3;
  static const double streamLoadingSpinnerStrokeTv =
      streamLoadingSpinnerStroke * tvChromeScale;
  static const double streamLoadingSpinnerGap = 28;
  static const double streamLoadingSpinnerGapTv =
      streamLoadingSpinnerGap * tvChromeScale;
  static const double streamLoadingCancelGap = 24;
  static const double streamLoadingCancelGapTv =
      streamLoadingCancelGap * tvChromeScale;
  static const double streamLoadingCancelGapWithProbes = 20;
  static const double streamLoadingCancelGapWithProbesTv =
      streamLoadingCancelGapWithProbes * tvChromeScale;
  static const double streamLoadingTitleFontSize = 24;
  static const double streamLoadingTitleFontSizeTv = tvTitleFontSize;
  static const double streamLoadingTitlePadH = 40;
  static const double streamLoadingTitlePadHTv =
      streamLoadingTitlePadH * tvChromeScale;
  static const double streamLoadingHeadlineFontSize = 18;
  static const double streamLoadingHeadlineFontSizeTv = tvTitleFontSize;
  static const double streamLoadingHintFontSize = 13;
  static const double streamLoadingHintFontSizeTv = tvBodyFontSize;
  static const double streamLoadingHintGap = 8;
  static const double streamLoadingHintGapTv =
      streamLoadingHintGap * tvChromeScale;
  static const double streamLoadingHintPadH = 20;
  static const double streamLoadingHintPadHTv =
      streamLoadingHintPadH * tvChromeScale;
  static const double streamLoadingMetaFontSize = 11;
  static const double streamLoadingMetaFontSizeTv = tvMetaFontSize;
  static const double streamLoadingTipFontSize = 10;
  static const double streamLoadingTipFontSizeTv = tvMetaFontSize;
  static const double streamLoadingProgressWidth = 220;
  static const double streamLoadingProgressWidthTv =
      streamLoadingProgressWidth * tvChromeScale;
  static const double streamLoadingProgressHeight = 3;
  static const double streamLoadingProgressHeightTv = 2.5;
  static const double streamLoadingProgressGap = 22;
  static const double streamLoadingProgressGapTv =
      streamLoadingProgressGap * tvChromeScale;
  static const double streamLoadingProgressMetaGap = 10;
  static const double streamLoadingProgressMetaGapTv =
      streamLoadingProgressMetaGap * tvChromeScale;
  static const double streamLoadingCancelPadH = 32;
  static const double streamLoadingCancelPadHTv =
      streamLoadingCancelPadH * tvChromeScale;
  static const double streamLoadingCancelPadV = 12;
  static const double streamLoadingCancelPadVTv =
      streamLoadingCancelPadV * tvChromeScale;
  static const double streamLoadingCancelFontSize = 13;
  static const double streamLoadingCancelFontSizeTv = tvBodyFontSize;
  static const double streamLoadingCancelRadius = 24;
  static const double streamLoadingCancelRadiusTv =
      streamLoadingCancelRadius * tvChromeScale;
  static const double streamLoadingServersChipPad = 12;
  static const double streamLoadingServersChipPadTv =
      streamLoadingServersChipPad * tvChromeScale;
  static const double streamLoadingActionGap = 10;
  static const double streamLoadingActionGapTv =
      streamLoadingActionGap * tvChromeScale;
  static const double streamLoadingProviderListMaxHeight = 220;
  static const double streamLoadingProviderListMaxHeightTv =
      streamLoadingProviderListMaxHeight * tvChromeScale;
  static const double streamLoadingProviderListMaxWidth = 360;
  static const double streamLoadingProviderListMaxWidthTv =
      streamLoadingProviderListMaxWidth * tvChromeScale;
  static const double streamLoadingProviderListRadius = 12;
  static const double streamLoadingProviderListRadiusTv =
      streamLoadingProviderListRadius * tvChromeScale;
  static const double streamLoadingProviderListPadV = 6;
  static const double streamLoadingProviderListPadVTv =
      streamLoadingProviderListPadV * tvChromeScale;
  static const double streamLoadingProviderRowPadH = 14;
  static const double streamLoadingProviderRowPadHTv =
      streamLoadingProviderRowPadH * tvChromeScale;
  static const double streamLoadingProviderRowPadV = 10;
  static const double streamLoadingProviderRowPadVTv =
      streamLoadingProviderRowPadV * tvChromeScale;
  static const double streamLoadingProviderLabelFontSize = 12;
  static const double streamLoadingProviderLabelFontSizeTv = tvBodyFontSize;
  static const double streamLoadingProviderStatusFontSize = 10;
  static const double streamLoadingProviderStatusFontSizeTv = tvMetaFontSize;
  static const double streamLoadingProviderGlyph = 14;
  static const double streamLoadingProviderGlyphTv =
      streamLoadingProviderGlyph * tvChromeScale;
  static const double streamLoadingProviderPendingDot = 8;
  static const double streamLoadingProviderPendingDotTv =
      streamLoadingProviderPendingDot * tvChromeScale;
  static const double streamLoadingProviderGlyphGap = 10;
  static const double streamLoadingProviderGlyphGapTv =
      streamLoadingProviderGlyphGap * tvChromeScale;
  static const double streamLoadingProviderStar = 14;
  static const double streamLoadingProviderStarTv =
      streamLoadingProviderStar * tvChromeScale;
  static const double streamLoadingProviderListGap = 16;
  static const double streamLoadingProviderListGapTv =
      streamLoadingProviderListGap * tvChromeScale;
  static const double streamLoadingProviderTipGap = 12;
  static const double streamLoadingProviderTipGapTv =
      streamLoadingProviderTipGap * tvChromeScale;
  static const double streamLoadingStatsMaxWidth = 420;
  static const double streamLoadingStatsMaxWidthTv =
      streamLoadingStatsMaxWidth * tvChromeScale;
  static const double streamLoadingStatsRadius = 14;
  static const double streamLoadingStatsRadiusTv =
      streamLoadingStatsRadius * tvChromeScale;
  static const double streamLoadingStatsPadH = 12;
  static const double streamLoadingStatsPadHTv =
      streamLoadingStatsPadH * tvChromeScale;
  static const double streamLoadingStatsPadV = 16;
  static const double streamLoadingStatsPadVTv =
      streamLoadingStatsPadV * tvChromeScale;
  static const double streamLoadingStatsIconSize = 18;
  static const double streamLoadingStatsIconSizeTv =
      streamLoadingStatsIconSize * tvChromeScale;
  static const double streamLoadingStatsValueFontSize = 15;
  static const double streamLoadingStatsValueFontSizeTv = tvTitleFontSize;
  static const double streamLoadingStatsLabelFontSize = 11;
  static const double streamLoadingStatsLabelFontSizeTv = tvMetaFontSize;
  static const double streamLoadingStatsIconGap = 8;
  static const double streamLoadingStatsIconGapTv =
      streamLoadingStatsIconGap * tvChromeScale;
  static const double streamLoadingStatsValueGap = 4;
  static const double streamLoadingStatsValueGapTv =
      streamLoadingStatsValueGap * tvChromeScale;
  static const double streamLoadingStatsDividerHeight = 44;
  static const double streamLoadingStatsDividerHeightTv =
      streamLoadingStatsDividerHeight * tvChromeScale;
  static const double streamLoadingStatsDividerMargin = 4;
  static const double streamLoadingStatsDividerMarginTv =
      streamLoadingStatsDividerMargin * tvChromeScale;
  static const double streamLoadingFailureMaxWidth = 420;
  static const double streamLoadingFailureMaxWidthTv =
      streamLoadingFailureMaxWidth * tvChromeScale;
  static const double streamLoadingFailureIconCompact = 40;
  static const double streamLoadingFailureIconCompactTv =
      streamLoadingFailureIconCompact * tvChromeScale;
  static const double streamLoadingFailureIcon = 52;
  static const double streamLoadingFailureIconTv =
      streamLoadingFailureIcon * tvChromeScale;
  static const double streamLoadingFailureIconPad = 28;
  static const double streamLoadingFailureIconPadTv =
      streamLoadingFailureIconPad * tvChromeScale;
  static const double streamLoadingFailureTitleFontSize = 22;
  static const double streamLoadingFailureTitleFontSizeTv = tvTitleFontSize;
  static const double streamLoadingFailureTitleFontSizeCompact = 18;
  static const double streamLoadingFailureTitleFontSizeCompactTv = tvTitleFontSize;
  static const double streamLoadingFailureDetailFontSize = 14;
  static const double streamLoadingFailureDetailFontSizeTv = tvBodyFontSize;
  static const double streamLoadingFailureDetailFontSizeCompact = 13;
  static const double streamLoadingFailureDetailFontSizeCompactTv = tvBodyFontSize;
  static const double streamLoadingFailureButtonPadH = 22;
  static const double streamLoadingFailureButtonPadHTv =
      streamLoadingFailureButtonPadH * tvChromeScale;
  static const double streamLoadingFailureButtonPadV = 14;
  static const double streamLoadingFailureButtonPadVTv =
      streamLoadingFailureButtonPadV * tvChromeScale;
  static const double streamLoadingFailureButtonFontSize = 14;
  static const double streamLoadingFailureButtonFontSizeTv = tvBodyFontSize;
  static const double streamLoadingFailureSecondaryFontSize = 13;
  static const double streamLoadingFailureSecondaryFontSizeTv = tvBodyFontSize;
  static const double streamLoadingFailureButtonRadius = 12;
  static const double streamLoadingFailureButtonRadiusTv =
      streamLoadingFailureButtonRadius * tvChromeScale;
  static const double streamLoadingFailureIconGap = 8;
  static const double streamLoadingFailureIconGapTv =
      streamLoadingFailureIconGap * tvChromeScale;
  static const double streamLoadingFailureTitleGap = 20;
  static const double streamLoadingFailureTitleGapTv =
      streamLoadingFailureTitleGap * tvChromeScale;
  static const double streamLoadingFailureTitleGapCompact = 16;
  static const double streamLoadingFailureTitleGapCompactTv =
      streamLoadingFailureTitleGapCompact * tvChromeScale;
  static const double streamLoadingFailureDetailGap = 10;
  static const double streamLoadingFailureDetailGapTv =
      streamLoadingFailureDetailGap * tvChromeScale;
  static const double streamLoadingFailureDetailGapCompact = 8;
  static const double streamLoadingFailureDetailGapCompactTv =
      streamLoadingFailureDetailGapCompact * tvChromeScale;
  static const double streamLoadingFailureActionsGap = 28;
  static const double streamLoadingFailureActionsGapTv =
      streamLoadingFailureActionsGap * tvChromeScale;
  static const double streamLoadingFailureActionsGapCompact = 22;
  static const double streamLoadingFailureActionsGapCompactTv =
      streamLoadingFailureActionsGapCompact * tvChromeScale;
  static const double streamLoadingFailureSecondaryGap = 6;
  static const double streamLoadingFailureSecondaryGapTv =
      streamLoadingFailureSecondaryGap * tvChromeScale;
  static const double streamLoadingFailureSecondaryPadH = 16;
  static const double streamLoadingFailureSecondaryPadHTv =
      streamLoadingFailureSecondaryPadH * tvChromeScale;
  static const double streamLoadingFailureSecondaryPadV = 10;
  static const double streamLoadingFailureSecondaryPadVTv =
      streamLoadingFailureSecondaryPadV * tvChromeScale;
  static const double streamLoadingBannerGap = 14;
  static const double streamLoadingBannerGapTv =
      streamLoadingBannerGap * tvChromeScale;
  static const double streamLoadingReloadGap = 12;
  static const double streamLoadingReloadGapTv =
      streamLoadingReloadGap * tvChromeScale;
  static const double streamLoadingReloadButtonGap = 16;
  static const double streamLoadingReloadButtonGapTv =
      streamLoadingReloadButtonGap * tvChromeScale;
  static const double streamLoadingReloadButtonPadH = 22;
  static const double streamLoadingReloadButtonPadHTv =
      streamLoadingReloadButtonPadH * tvChromeScale;
  static const double streamLoadingReloadButtonPadV = 10;
  static const double streamLoadingReloadButtonPadVTv =
      streamLoadingReloadButtonPadV * tvChromeScale;

  static const double eventSearchCollapsed = controlHeight;
  static const double eventSearchCollapsedTv = controlHeightTv;
  static const double eventSearchExpanded = 260;
  static const double eventSearchExpandedTv =
      eventSearchExpanded * tvChromeScale;
  static const double eventSearchFontSize = 13;
  static const double eventSearchFontSizeTv = tvBodyFontSize;
  static const double eventSearchIconSize = 20;
  static const double eventSearchIconSizeTv = actionChipIconSizeTv;
  static const double eventSearchClearIconSize = 18;
  static const double eventSearchClearIconSizeTv = actionChipIconSizeTv;

  /// Generic form / dialog / sheet text fields (account, kit [Input], bind sheets).
  /// Type family on TV — never × [tvChromeScale].
  static const double formInputFontSize = 14;
  static const double formInputFontSizeTv = tvBodyFontSize;
  static const double formInputLabelFontSize = 12;
  static const double formInputLabelFontSizeTv = tvMetaFontSize;
  static const double formInputHintFontSize = 14;
  static const double formInputHintFontSizeTv = tvMetaFontSize;
  static const double formInputIconSize = 20;
  static const double formInputIconSizeTv = formInputIconSize * tvChromeScale;
  static const double formInputPadH = 14;
  static const double formInputPadHTv = formInputPadH * tvChromeScale;
  static const double formInputPadV = 12;
  static const double formInputPadVTv = formInputPadV * tvChromeScale;
  static const double formInputPadHSm = 12;
  static const double formInputPadHSmTv = formInputPadHSm * tvChromeScale;
  static const double formInputPadVSm = 8;
  static const double formInputPadVSmTv = formInputPadVSm * tvChromeScale;
  static const double formInputFontSizeSm = 13;
  static const double formInputFontSizeSmTv = tvBodyFontSize;
  static const double formInputFontSizeLg = 16;
  static const double formInputFontSizeLgTv = tvTitleFontSize;
  static const double formInputIconSizeSm = 18;
  static const double formInputIconSizeSmTv = formInputIconSizeSm * tvChromeScale;
  static const double formInputIconSizeLg = 22;
  static const double formInputIconSizeLgTv = formInputIconSizeLg * tvChromeScale;
  static const double formInputPadHLg = 16;
  static const double formInputPadHLgTv = formInputPadHLg * tvChromeScale;
  static const double formInputPadVLg = 14;
  static const double formInputPadVLgTv = formInputPadVLg * tvChromeScale;

  static const double favStarIconSize = 14;
  static const double favStarIconSizeTv = favStarIconSize * tvChromeScale;
  static const double scrollerArrowOffset = 8;
  static const double scrollerArrowIconSize = 24;
  static const double scrollerArrowIconSizeTv =
      scrollerArrowIconSize * tvChromeScale;
  static const double filterSheetRadius = 12;
  static const double filterSheetRadiusTv = 10;
  static const double filterSheetHandleWidth = 40;
  static const double filterSheetHandleWidthTv = filterSheetHandleWidth * tvChromeScale;
  static const double filterSheetHandleHeight = 4;
  static const double filterSheetHandleHeightTv = 3;
  static const double filterSheetTitleFontSize = 16;
  static const double filterSheetTitleFontSizeTv = tvTitleFontSize;
  static const double filterSheetSubtitleFontSize = 13;
  static const double filterSheetSubtitleFontSizeTv = tvMetaFontSize;
  static const double filterSheetOptionFontSize = 16;
  static const double filterSheetOptionFontSizeTv = tvBodyFontSize;
  static const double filterSheetMetaFontSize = 11;
  static const double filterSheetMetaFontSizeTv = tvMetaFontSize;
  static const double filterSheetIconSize = 24;
  static const double filterSheetIconSizeTv = filterSheetIconSize * tvChromeScale;
  static const double filterSheetCheckSize = 22;
  static const double filterSheetCheckSizeTv = filterSheetCheckSize * tvChromeScale;
  static const double filterSheetPadH = 24;
  static const double filterSheetPadHTv = filterSheetPadH * tvChromeScale;
  static const double filterSheetPadTop = 20;
  static const double filterSheetPadTopTv = filterSheetPadTop * tvChromeScale;
  static const double filterSheetPadBottom = 32;
  static const double filterSheetPadBottomTv = filterSheetPadBottom * tvChromeScale;
  static const double filterSheetTitleGap = 20;
  static const double filterSheetTitleGapTv = filterSheetTitleGap * tvChromeScale;
  static const double filterSheetSubtitleGap = 6;
  static const double filterSheetSubtitleGapTv = 4;
  static const double filterSheetListGap = 16;
  static const double filterSheetListGapTv = filterSheetListGap * tvChromeScale;
  static const double filterSheetMaxHeightFraction = 0.7;
  static const double filterSheetMaxHeightFractionTv = 0.55;
  static const double filterSheetMaxWidthTv = 360;
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

  /// Top-right status toast column ([ForjaToastHost]).
  ///
  /// Chrome (width / pad / icons) × [tvChromeScale]; message type uses
  /// [tvTypeSize] — do not chrome-scale fonts.
  static const double toastWidth = 360;
  static const double toastInset = 16;
  static const double toastStackGap = 8;
  static const double toastCardPadL = 12;
  static const double toastCardPadT = 10;
  static const double toastCardPadR = 8;
  static const double toastCardPadB = 10;
  static const double toastRadius = 10;
  static const double toastAccentBarWidth = 4;
  static const double toastIconSize = 18;
  static const double toastMessageFontSize = 13;
  static const double toastActionFontSize = 12;
  static const double toastCloseSize = 28;
  static const double toastCloseIconSize = 16;
  static const double toastProgressHeight = 2;
  static const double toastMessageIconGap = 10;
  static const double toastActionGap = 8;
  static const double toastActionPadH = 8;
  static const double toastActionPadV = 6;

  /// Film-poster spatial ratio (card radius / local chrome on posters).
  /// Pack chrome lengths use [tvChromeScale] via [chromeScale], not this.
  static double get tvLayoutScale => posterCardWidthTv / posterCardWidthDesktop;

  /// Grid inset beside a category rail (Live / Movies / Series).
  ///
  /// Not [compactChromeLeadingInset] — the rail already clears the ☰ lane.
  static const double catalogSplitGridLeadingPad = 8;

  static const double catalogSplitGridTrailingPad = 12;

  /// Hot strip on the window's left edge — hover opens the compact nav drawer.
  static const double compactNavEdgeHoverWidth = 12;

  /// Portal / OTP share-code cells (Add Portal collapsed).
  static const double shareCodeCellWidth = 38;
  static const double shareCodeCellWidthTv = 22;
  static const double shareCodeCellHeight = 76;
  static const double shareCodeCellHeightTv = 30;
  static const double shareCodeCellGap = 6;
  static const double shareCodeCellGapTv = 4;
  static const double shareCodeCellRadius = 8;
  static const double shareCodeCellRadiusTv = 5;
  static const double shareCodeFontSize = 26;
  static const double shareCodeFontSizeTv = tvTitleFontSize;
  static const double shareCodeExpandSize = 38;
  static const double shareCodeExpandSizeTv = 26;
  static const double shareCodeCollapsedBodyHeight = 196;
  static const double shareCodeCollapsedBodyHeightTv = 108;
  static const double shareCodeDialogWidth = 440;
  static const double shareCodeDialogWidthTv = 320;

  static const double packUpdateMenuBadgeFontSize = 10;
  static const double packUpdateMenuBadgeFontSizeTv = tvMetaFontSize;
  static const double packUpdateMenuBadgePadH = 6;
  static const double packUpdateMenuBadgePadHTv =
      packUpdateMenuBadgePadH * tvChromeScale;
  static const double packUpdateMenuBadgePadV = 2;
  static const double packUpdateMenuBadgePadVTv = 1;
  static const double packUpdateMenuBadgeRadius = 4;
  static const double packUpdateMenuBadgeRadiusTv =
      packUpdateMenuBadgeRadius * tvChromeScale;

  static const double packUpdateSettingsIconSize = 24;

  /// Compact ☰ glyph — smaller than rail destination icons.
  static const double shellNavMenuButtonIconSize = 22;

  /// TV shell header top pad — leanback keeps desktop pad (not × poster scale).
  static const double shellHeaderTopPaddingTv = shellHeaderTopPadding;

  /// Scale a desktop token by [tvLayoutScale] when [tv] is true.
  static double densityScale(double value, {required bool tv}) =>
      tv ? value * tvLayoutScale : value;

  /// Scale desktop chrome by [tvChromeScale] when [tv] is true.
  static double chromeScale(double value, {required bool tv, double min = 0}) {
    if (!tv) return value;
    final s = value * tvChromeScale;
    return s < min ? min : s;
  }

  /// Material default icon size (Icons without an explicit [Icon.size]).
  static const double iconSize = 24;

  /// Leanback default for [IconTheme] / [IconButton] when size is unset.
  static const double iconSizeTv = iconSize * tvChromeScale;

  /// Desktop icon px → leanback chrome. Prefer named `*IconSizeTv` tokens when
  /// they exist; use this for one-off desktop baselines.
  static double iconSizeFor(double desktop, {required bool tv}) =>
      chromeScale(desktop, tv: tv);

  /// Title top inset for a standard Home row (pairs with [homeRowSpacing]).
  static const double homeSectionTitleTop = 36;
  static const double homeSectionTitleTopCompactDesktop = 16;
  static const double homeSectionTitleTopCompactMobile = 32;
  static const double searchCardWidthDesktop = 140;
  static const double searchCardWidthCompact = 120;

  /// Leanback search result cells — chrome family (not film poster width).
  static const double searchCardWidthTv =
      searchCardWidthDesktop * tvChromeScale;

  /// Wide search results grid columns (film cards fill each cell).
  static const int searchResultsGridColumns = 4;

  /// Leanback search results — **max** columns. Host packs by
  /// [posterCardWidthTv] so cards stay readable beside the helpers rail
  /// (never force a skinny 6-up crush).
  static const int searchResultsGridColumnsTv = 5;

  /// Netflix-style search: input column on desktop.
  static const double searchPageInset = 32;
  static const double searchPageInsetTv = searchPageInset * tvChromeScale;

  /// Top inset for desktop search - aligns with Home hero text clearance.
  static double get searchPageTopInset => homeTopBarHeight + 24;
  static const double searchColumnGap = 32;
  static const double searchColumnGapTv = searchColumnGap * tvChromeScale;
  static const double searchFieldBelowGap = 24;
  static const double searchFieldBelowGapTv =
      searchFieldBelowGap * tvChromeScale;
  static const double searchLeftColumnWidth = 420;
  static const double searchLeftColumnPadding = 16;

  /// Hub search query field — display size on desktop; type ladder on TV.
  static const double searchQueryFontSize = 32;
  static const double searchQueryFontSizeTv = tvTitleFontSize;
  static const double searchQueryCursorHeight = 36;
  static const double searchQueryCursorHeightTv =
      searchQueryFontSizeTv * 1.15;

  /// Hub search recent / recommendation rows.
  static const double searchHelperFontSize = 15;
  static const double searchHelperFontSizeTv = tvBodyFontSize;
  static const double searchHelperFontSizeSelected = 17;
  static const double searchHelperFontSizeSelectedTv = tvTitleFontSize;
  static const double searchHelperVerticalPadding = 8;
  static const double searchHelperVerticalPaddingTv =
      searchHelperVerticalPadding * tvChromeScale;
  static const double searchHelperIconSize = 13;
  static const double searchHelperIconSizeSelected = 15;
  static const double searchHelperIconSizeTv = tvMetaFontSize;
  static const double searchHelperIconSizeSelectedTv = tvBodyFontSize;

  /// Hub search filter lens (type / score / year / chips / submit).
  /// Chrome pads × [tvChromeScale]; labels use the type ladder on TV.
  static const double searchFilterSectionLabelFontSize = 11;
  static const double searchFilterSectionLabelFontSizeTv = tvMetaFontSize;
  static const double searchFilterValueFontSize = 12;
  static const double searchFilterValueFontSizeTv = tvBodyFontSize;
  static const double searchFilterAxisFontSize = 10;
  static const double searchFilterAxisFontSizeTv = tvMetaFontSize;
  static const double searchFilterSectionGap = 8;
  static const double searchFilterSectionGapTv =
      searchFilterSectionGap * tvChromeScale;
  static const double searchFilterBlockGap = 14;
  static const double searchFilterBlockGapTv =
      searchFilterBlockGap * tvChromeScale;
  static const double searchFilterChipBlockGap = 16;
  static const double searchFilterChipBlockGapTv =
      searchFilterChipBlockGap * tvChromeScale;
  static const double searchFilterSubmitGap = 20;
  static const double searchFilterSubmitGapTv =
      searchFilterSubmitGap * tvChromeScale;
  static const double searchFilterTopPad = 12;
  static const double searchFilterTopPadTv =
      searchFilterTopPad * tvChromeScale;
  static const double searchFilterScoreTrackHeight = 28;
  static const double searchFilterScoreTrackHeightTv =
      searchFilterScoreTrackHeight * tvChromeScale;
  static const double searchFilterYearTrackHeight = 32;
  static const double searchFilterYearTrackHeightTv =
      searchFilterYearTrackHeight * tvChromeScale;
  static const double searchFilterTrackPadV = 6;
  static const double searchFilterTrackPadVTv =
      searchFilterTrackPadV * tvChromeScale;
  static const double searchFilterTrackPadH = 4;
  static const double searchFilterTrackPadHTv =
      searchFilterTrackPadH * tvChromeScale;
  static const double searchFilterTrackRadius = 10;
  static const double searchFilterTrackRadiusTv =
      searchFilterTrackRadius * tvChromeScale;
  static const double searchFilterAxisGap = 4;
  static const double searchFilterAxisGapTv =
      searchFilterAxisGap * tvChromeScale;
  static const double searchFilterGhostChipPadH = 11;
  static const double searchFilterGhostChipPadHTv =
      searchFilterGhostChipPadH * tvChromeScale;
  static const double searchFilterGhostChipPadV = 6;
  static const double searchFilterGhostChipPadVTv =
      searchFilterGhostChipPadV * tvChromeScale;
  static const double searchFilterGhostChipRadius = 16;
  static const double searchFilterGhostChipRadiusTv =
      searchFilterGhostChipRadius * tvChromeScale;
  static const double searchFilterGhostChipFontSize = 12;
  static const double searchFilterGhostChipFontSizeTv = tvBodyFontSize;
  static const double searchFilterChipWrapGap = 8;
  static const double searchFilterChipWrapGapTv =
      searchFilterChipWrapGap * tvChromeScale;
  static const double searchFilterSubmitPadH = 18;
  static const double searchFilterSubmitPadHTv =
      searchFilterSubmitPadH * tvChromeScale;
  static const double searchFilterSubmitPadV = 12;
  static const double searchFilterSubmitPadVTv =
      searchFilterSubmitPadV * tvChromeScale;
  static const double searchFilterTokenPadLead = 10;
  static const double searchFilterTokenPadLeadTv =
      searchFilterTokenPadLead * tvChromeScale;
  static const double searchFilterTokenPadTrail = 6;
  static const double searchFilterTokenPadTrailTv =
      searchFilterTokenPadTrail * tvChromeScale;
  static const double searchFilterTokenPadV = 4;
  static const double searchFilterTokenPadVTv =
      searchFilterTokenPadV * tvChromeScale;
  static const double searchFilterTokenRadius = 16;
  static const double searchFilterTokenRadiusTv =
      searchFilterTokenRadius * tvChromeScale;
  static const double searchFilterTokenFontSize = 12;
  static const double searchFilterTokenFontSizeTv = tvBodyFontSize;
  static const double searchFilterTokenIconSize = 14;
  static const double searchFilterTokenIconSizeTv =
      searchFilterTokenIconSize * tvChromeScale;
  static const double searchFilterTokenIconGap = 2;
  static const double searchFilterTokenIconGapTv =
      searchFilterTokenIconGap * tvChromeScale;
  static const double searchFilterTuneIconSize = 24;
  static const double searchFilterTuneIconSizeTv =
      searchFilterTuneIconSize * tvChromeScale;

  static double searchFilterSectionLabelFontSizeOf(bool tv) => tv
      ? searchFilterSectionLabelFontSizeTv
      : searchFilterSectionLabelFontSize;
  static double searchFilterValueFontSizeOf(bool tv) =>
      tv ? searchFilterValueFontSizeTv : searchFilterValueFontSize;
  static double searchFilterAxisFontSizeOf(bool tv) =>
      tv ? searchFilterAxisFontSizeTv : searchFilterAxisFontSize;
  static double searchFilterSectionGapOf(bool tv) =>
      tv ? searchFilterSectionGapTv : searchFilterSectionGap;
  static double searchFilterBlockGapOf(bool tv) =>
      tv ? searchFilterBlockGapTv : searchFilterBlockGap;
  static double searchFilterChipBlockGapOf(bool tv) =>
      tv ? searchFilterChipBlockGapTv : searchFilterChipBlockGap;
  static double searchFilterSubmitGapOf(bool tv) =>
      tv ? searchFilterSubmitGapTv : searchFilterSubmitGap;
  static double searchFilterTopPadOf(bool tv) =>
      tv ? searchFilterTopPadTv : searchFilterTopPad;
  static double searchFilterScoreTrackHeightOf(bool tv) =>
      tv ? searchFilterScoreTrackHeightTv : searchFilterScoreTrackHeight;
  static double searchFilterYearTrackHeightOf(bool tv) =>
      tv ? searchFilterYearTrackHeightTv : searchFilterYearTrackHeight;
  static double searchFilterTrackPadVOf(bool tv) =>
      tv ? searchFilterTrackPadVTv : searchFilterTrackPadV;
  static double searchFilterTrackPadHOf(bool tv) =>
      tv ? searchFilterTrackPadHTv : searchFilterTrackPadH;
  static double searchFilterTrackRadiusOf(bool tv) =>
      tv ? searchFilterTrackRadiusTv : searchFilterTrackRadius;
  static double searchFilterAxisGapOf(bool tv) =>
      tv ? searchFilterAxisGapTv : searchFilterAxisGap;
  static double searchFilterGhostChipPadHOf(bool tv) =>
      tv ? searchFilterGhostChipPadHTv : searchFilterGhostChipPadH;
  static double searchFilterGhostChipPadVOf(bool tv) =>
      tv ? searchFilterGhostChipPadVTv : searchFilterGhostChipPadV;
  static double searchFilterGhostChipRadiusOf(bool tv) =>
      tv ? searchFilterGhostChipRadiusTv : searchFilterGhostChipRadius;
  static double searchFilterGhostChipFontSizeOf(bool tv) =>
      tv ? searchFilterGhostChipFontSizeTv : searchFilterGhostChipFontSize;
  static double searchFilterChipWrapGapOf(bool tv) =>
      tv ? searchFilterChipWrapGapTv : searchFilterChipWrapGap;
  static double searchFilterSubmitPadHOf(bool tv) =>
      tv ? searchFilterSubmitPadHTv : searchFilterSubmitPadH;
  static double searchFilterSubmitPadVOf(bool tv) =>
      tv ? searchFilterSubmitPadVTv : searchFilterSubmitPadV;
  static double searchFilterTuneIconSizeOf(bool tv) =>
      tv ? searchFilterTuneIconSizeTv : searchFilterTuneIconSize;

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
