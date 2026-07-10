import 'package:forja/shared/design/src/shell_tokens.dart';

/// Profile-specific layout sizes. Shared colors/typography stay in [ForjaShellColors].
class ShellMetrics {
  const ShellMetrics({
    required this.homeMovieCardWidth,
    required this.continueWatchingCardWidth,
    required this.continueWatchingCardHeight,
    required this.hubCardTitleFontSize,
    required this.heroCompactRightInset,
    required this.heroMinTitleHeight,
    required this.heroActionUseFittedBox,
    required this.navRailSafeAreaVertical,
    required this.allowCompactNavDrawer,
    required this.torrentPanelPadding,
    required this.torrentPanelTitleFontSize,
    required this.torrentPanelChipHorizontalPadding,
    required this.torrentPanelChipVerticalPadding,
    required this.torrentPanelChipFontSize,
    required this.torrentPanelMetaIconSize,
    required this.torrentPanelMetaFontSize,
    required this.torrentPanelLeadingIconSize,
    required this.torrentPanelSectionFontSize,
    required this.usesTvDensity,
  });

  final double homeMovieCardWidth;
  final double continueWatchingCardWidth;
  final double continueWatchingCardHeight;
  final double hubCardTitleFontSize;
  final double heroCompactRightInset;
  final double heroMinTitleHeight;
  final bool heroActionUseFittedBox;
  final bool navRailSafeAreaVertical;
  final bool allowCompactNavDrawer;
  final double torrentPanelPadding;
  final double torrentPanelTitleFontSize;
  final double torrentPanelChipHorizontalPadding;
  final double torrentPanelChipVerticalPadding;
  final double torrentPanelChipFontSize;
  final double torrentPanelMetaIconSize;
  final double torrentPanelMetaFontSize;
  final double torrentPanelLeadingIconSize;
  final double torrentPanelSectionFontSize;
  final bool usesTvDensity;

  static const mobile = ShellMetrics(
    homeMovieCardWidth: 165,
    continueWatchingCardWidth: ShellTokens.shellContinueWatchingCardWidthCompact,
    continueWatchingCardHeight: ShellTokens.shellContinueWatchingCardHeightCompact,
    hubCardTitleFontSize: 13,
    heroCompactRightInset: 20,
    heroMinTitleHeight: 72,
    heroActionUseFittedBox: false,
    navRailSafeAreaVertical: true,
    allowCompactNavDrawer: true,
    torrentPanelPadding: 16,
    torrentPanelTitleFontSize: 16,
    torrentPanelChipHorizontalPadding: 12,
    torrentPanelChipVerticalPadding: 8,
    torrentPanelChipFontSize: 12,
    torrentPanelMetaIconSize: 14,
    torrentPanelMetaFontSize: 11,
    torrentPanelLeadingIconSize: 22,
    torrentPanelSectionFontSize: 16,
    usesTvDensity: false,
  );

  static const desktop = ShellMetrics(
    homeMovieCardWidth: 190,
    continueWatchingCardWidth: ShellTokens.shellContinueWatchingCardWidthDesktop,
    continueWatchingCardHeight: ShellTokens.shellContinueWatchingCardHeightDesktop,
    hubCardTitleFontSize: 14,
    heroCompactRightInset: 20,
    heroMinTitleHeight: 72,
    heroActionUseFittedBox: false,
    navRailSafeAreaVertical: true,
    allowCompactNavDrawer: true,
    torrentPanelPadding: 16,
    torrentPanelTitleFontSize: 16,
    torrentPanelChipHorizontalPadding: 12,
    torrentPanelChipVerticalPadding: 8,
    torrentPanelChipFontSize: 12,
    torrentPanelMetaIconSize: 14,
    torrentPanelMetaFontSize: 11,
    torrentPanelLeadingIconSize: 22,
    torrentPanelSectionFontSize: 16,
    usesTvDensity: false,
  );

  static const tv = ShellMetrics(
    homeMovieCardWidth: 220,
    continueWatchingCardWidth: 300,
    continueWatchingCardHeight: 300 * 9 / 16,
    hubCardTitleFontSize: 15,
    heroCompactRightInset: 88,
    heroMinTitleHeight: 0,
    heroActionUseFittedBox: true,
    navRailSafeAreaVertical: false,
    allowCompactNavDrawer: false,
    torrentPanelPadding: 24,
    torrentPanelTitleFontSize: 18,
    torrentPanelChipHorizontalPadding: 16,
    torrentPanelChipVerticalPadding: 10,
    torrentPanelChipFontSize: 14,
    torrentPanelMetaIconSize: 16,
    torrentPanelMetaFontSize: 12,
    torrentPanelLeadingIconSize: 26,
    torrentPanelSectionFontSize: 18,
    usesTvDensity: true,
  );

  double get navRailWidth => ShellTokens.navRailWidth;
}
