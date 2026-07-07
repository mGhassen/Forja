/// Layout constants for the app shell nav chrome.
abstract final class ShellTokens {
  static const double bottomNavHeight = 80;
  static const double bottomNavItemWidth = 100;
  static const double bottomNavIconPaddingH = 20;
  static const double bottomNavIconPaddingV = 4;
  static const double bottomNavLabelSize = 11;
  static const double bottomNavFadeWidth = 40;

  static const double navRailCollapsedWidth = 56;
  static const double navRailExpandedWidth = 220;
  static const Duration navRailExpandDuration = Duration(milliseconds: 200);

  static const double navRailLogoWidth = 48;
  static const double navRailLogoBottomPadding = 24;
  static const double navRailLogoTopPaddingDesktopMac = 8;
  static const double navRailLogoTopPaddingDefault = 24;

  /// Music desktop sidebar width — global rail hidden when Music tab uses this.
  static const double musicDesktopSidebarWidth = 260;
  static const double musicDesktopBreakpoint = 900;

  static const double heroImageWidthFraction = 2 / 3;
  static const double heroTextWidthFraction = 1 / 3;
  static const double heroMinHeightDesktop = 480;

  static const double bodyHorizontalPadding = 20;
  static const double bodyMaxWidthDesktop = 1600;
  static const double tabHeaderTopPadding = 16;
  static const double tabHeaderBottomPadding = 12;
  static const double tabHeaderFontSize = 32;

  static const double sectionTopSpacing = 20;
  static const double searchCardWidthDesktop = 140;
  static const double searchCardWidthCompact = 120;
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
}
