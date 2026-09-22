import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Profile-specific layout sizes. Shared colors/typography stay in [ForjaShellColors].
///
/// Numeric values come from [ShellTokens] — this table only picks the profile.
class ShellMetrics {
  const ShellMetrics({
    required this.posterCardWidth,
    required this.hubCardTitleFontSize,
    required this.heroCompactRightInset,
    required this.heroMinTitleHeight,
    required this.heroActionUseFittedBox,
    required this.navRailSafeAreaVertical,
    required this.allowCompactNavDrawer,
    required this.torrentPanelPadding,
    required this.torrentPanelTitleFontSize,
    required this.torrentPanelRowTitleFontSize,
    required this.torrentPanelRowPadH,
    required this.torrentPanelRowPadV,
    required this.torrentPanelChipHorizontalPadding,
    required this.torrentPanelChipVerticalPadding,
    required this.torrentPanelChipFontSize,
    required this.torrentPanelMetaIconSize,
    required this.torrentPanelMetaFontSize,
    required this.torrentPanelLeadingIconSize,
    required this.torrentPanelSectionFontSize,
    required this.usesTvDensity,
    required this.navRailWidth,
    required this.navRailItemSpacing,
    required this.navRailLogoGap,
    required this.navRailLogoWidth,
    required this.navRailTopPadding,
    required this.navRailBottomPadding,
  });

  final double posterCardWidth;
  final double hubCardTitleFontSize;
  final double heroCompactRightInset;
  final double heroMinTitleHeight;
  final bool heroActionUseFittedBox;
  final bool navRailSafeAreaVertical;
  final bool allowCompactNavDrawer;
  final double torrentPanelPadding;
  final double torrentPanelTitleFontSize;
  final double torrentPanelRowTitleFontSize;
  final double torrentPanelRowPadH;
  final double torrentPanelRowPadV;
  final double torrentPanelChipHorizontalPadding;
  final double torrentPanelChipVerticalPadding;
  final double torrentPanelChipFontSize;
  final double torrentPanelMetaIconSize;
  final double torrentPanelMetaFontSize;
  final double torrentPanelLeadingIconSize;
  final double torrentPanelSectionFontSize;
  final bool usesTvDensity;
  final double navRailWidth;
  final double navRailItemSpacing;
  final double navRailLogoGap;
  final double navRailLogoWidth;
  final double navRailTopPadding;
  final double navRailBottomPadding;

  double get navRailLogoHeight => navRailLogoWidth * 160 / 370;

  static const mobile = ShellMetrics(
    posterCardWidth: ShellTokens.posterCardWidthMobile,
    hubCardTitleFontSize: ShellTokens.hubCardTitleFontSizeMobile,
    heroCompactRightInset: ShellTokens.heroCompactRightInsetDesktop,
    heroMinTitleHeight: ShellTokens.heroMinTitleHeightDesktop,
    heroActionUseFittedBox: false,
    navRailSafeAreaVertical: true,
    allowCompactNavDrawer: true,
    torrentPanelPadding: ShellTokens.torrentPanelPaddingDesktop,
    torrentPanelTitleFontSize: ShellTokens.torrentPanelTitleFontSizeDesktop,
    torrentPanelRowTitleFontSize: ShellTokens.torrentPanelRowTitleFontSizeDesktop,
    torrentPanelRowPadH: ShellTokens.torrentPanelRowPadHDesktop,
    torrentPanelRowPadV: ShellTokens.torrentPanelRowPadVDesktop,
    torrentPanelChipHorizontalPadding: ShellTokens.torrentPanelChipPadHDesktop,
    torrentPanelChipVerticalPadding: ShellTokens.torrentPanelChipPadVDesktop,
    torrentPanelChipFontSize: ShellTokens.torrentPanelChipFontSizeDesktop,
    torrentPanelMetaIconSize: ShellTokens.torrentPanelMetaIconSizeDesktop,
    torrentPanelMetaFontSize: ShellTokens.torrentPanelMetaFontSizeDesktop,
    torrentPanelLeadingIconSize: ShellTokens.torrentPanelLeadingIconSizeDesktop,
    torrentPanelSectionFontSize: ShellTokens.torrentPanelSectionFontSizeDesktop,
    usesTvDensity: false,
    navRailWidth: ShellTokens.navRailWidth,
    navRailItemSpacing: ShellTokens.navRailItemSpacing,
    navRailLogoGap: ShellTokens.navRailLogoGapDesktop,
    navRailLogoWidth: ShellTokens.navRailLogoWidth,
    navRailTopPadding: ShellTokens.shellHeaderTopPadding,
    navRailBottomPadding: ShellTokens.navRailBottomPaddingDesktop,
  );

  static const desktop = ShellMetrics(
    posterCardWidth: ShellTokens.posterCardWidthDesktop,
    hubCardTitleFontSize: ShellTokens.hubCardTitleFontSizeDesktop,
    heroCompactRightInset: ShellTokens.heroCompactRightInsetDesktop,
    heroMinTitleHeight: ShellTokens.heroMinTitleHeightDesktop,
    heroActionUseFittedBox: false,
    navRailSafeAreaVertical: true,
    allowCompactNavDrawer: true,
    torrentPanelPadding: ShellTokens.torrentPanelPaddingDesktop,
    torrentPanelTitleFontSize: ShellTokens.torrentPanelTitleFontSizeDesktop,
    torrentPanelRowTitleFontSize: ShellTokens.torrentPanelRowTitleFontSizeDesktop,
    torrentPanelRowPadH: ShellTokens.torrentPanelRowPadHDesktop,
    torrentPanelRowPadV: ShellTokens.torrentPanelRowPadVDesktop,
    torrentPanelChipHorizontalPadding: ShellTokens.torrentPanelChipPadHDesktop,
    torrentPanelChipVerticalPadding: ShellTokens.torrentPanelChipPadVDesktop,
    torrentPanelChipFontSize: ShellTokens.torrentPanelChipFontSizeDesktop,
    torrentPanelMetaIconSize: ShellTokens.torrentPanelMetaIconSizeDesktop,
    torrentPanelMetaFontSize: ShellTokens.torrentPanelMetaFontSizeDesktop,
    torrentPanelLeadingIconSize: ShellTokens.torrentPanelLeadingIconSizeDesktop,
    torrentPanelSectionFontSize: ShellTokens.torrentPanelSectionFontSizeDesktop,
    usesTvDensity: false,
    navRailWidth: ShellTokens.navRailWidth,
    navRailItemSpacing: ShellTokens.navRailItemSpacing,
    navRailLogoGap: ShellTokens.navRailLogoGapDesktop,
    navRailLogoWidth: ShellTokens.navRailLogoWidth,
    navRailTopPadding: ShellTokens.shellHeaderTopPadding,
    navRailBottomPadding: ShellTokens.navRailBottomPaddingDesktop,
  );

  /// Leanback density — rows fill the body edge-to-edge after the nav rail.
  /// Rail width / logo use [ShellTokens.tvChromeScale]; posters use
  /// [ShellTokens.posterCardWidthTv] (film family).
  static const tv = ShellMetrics(
    posterCardWidth: ShellTokens.posterCardWidthTv,
    hubCardTitleFontSize: ShellTokens.hubCardTitleFontSizeTv,
    heroCompactRightInset: ShellTokens.heroCompactRightInsetTv,
    heroMinTitleHeight: ShellTokens.heroMinTitleHeightTv,
    heroActionUseFittedBox: false,
    navRailSafeAreaVertical: true,
    allowCompactNavDrawer: false,
    torrentPanelPadding: ShellTokens.torrentPanelPaddingTv,
    torrentPanelTitleFontSize: ShellTokens.torrentPanelTitleFontSizeTv,
    torrentPanelRowTitleFontSize: ShellTokens.torrentPanelRowTitleFontSizeTv,
    torrentPanelRowPadH: ShellTokens.torrentPanelRowPadHTv,
    torrentPanelRowPadV: ShellTokens.torrentPanelRowPadVTv,
    torrentPanelChipHorizontalPadding: ShellTokens.torrentPanelChipPadHTv,
    torrentPanelChipVerticalPadding: ShellTokens.torrentPanelChipPadVTv,
    torrentPanelChipFontSize: ShellTokens.torrentPanelChipFontSizeTv,
    torrentPanelMetaIconSize: ShellTokens.torrentPanelMetaIconSizeTv,
    torrentPanelMetaFontSize: ShellTokens.torrentPanelMetaFontSizeTv,
    torrentPanelLeadingIconSize: ShellTokens.torrentPanelLeadingIconSizeTv,
    torrentPanelSectionFontSize: ShellTokens.torrentPanelSectionFontSizeTv,
    usesTvDensity: true,
    navRailWidth: ShellTokens.navRailWidthTv,
    navRailItemSpacing: ShellTokens.navRailItemSpacingTv,
    navRailLogoGap: ShellTokens.navRailLogoGapTv,
    navRailLogoWidth: ShellTokens.navRailLogoWidthTv,
    navRailTopPadding: ShellTokens.navRailTopPaddingTv,
    navRailBottomPadding: ShellTokens.navRailBottomPaddingTv,
  );
}
