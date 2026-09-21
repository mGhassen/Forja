import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Layout tokens for portal list / probe chrome.
///
/// Row height / action rail are **hand-tuned** on TV (readable seats/meta).
/// Pads and hit boxes follow [ShellTokens.tvChromeScale]. Type uses the
/// leanback ladder. See density families on [ShellTokens].
abstract final class PortalListTokens {
  static const double rowHeight = 98;
  /// Hand — denser than desktop but room for seats/meta (not × chromeScale).
  static const double rowHeightTv = 72;
  static const double actionWidth = 108;
  static const double actionWidthTv = 72;
  static const double titleFontSize = 13;
  static const double titleFontSizeTv = ShellTokens.tvBodyFontSize;
  static const double metaFontSize = 11;
  static const double metaFontSizeTv = ShellTokens.tvMetaFontSize;
  static const double statusSlot = 18;
  static const double statusSlotTv = statusSlot * ShellTokens.tvChromeScale;
  static const double rowPadH = 12;
  static const double rowPadHTv = rowPadH * ShellTokens.tvChromeScale;
  static const double rowPadV = 10;
  static const double rowPadVTv = rowPadV * ShellTokens.tvChromeScale;
  static const double rowIconSize = 16;
  static const double rowIconSizeTv = ShellTokens.actionChipIconSizeTv;

  /// Hit box around a row action icon (copy / edit / trash).
  static const double rowActionHitSize = 32;
  static const double rowActionHitSizeTv =
      rowActionHitSize * ShellTokens.tvChromeScale;
  static const double metaIconSize = 12;
  static const double metaIconSizeTv = ShellTokens.tvMetaFontSize;
  static const double badgeFontSize = 9;
  static const double badgeFontSizeTv = ShellTokens.tvMetaFontSize;
  static const double badgeRadius = 4;
  static const double badgeRadiusTv = badgeRadius * ShellTokens.tvChromeScale;
  static const double chipRadius = 6;
  static const double chipRadiusTv = chipRadius * ShellTokens.tvChromeScale;
  static const double itemSpacing = 12;
  static const double itemSpacingTv = itemSpacing * ShellTokens.tvChromeScale;
  static const double panelPad = 12;
  static const double panelPadTv = panelPad * ShellTokens.tvChromeScale;
  static const double sectionGap = 8;
  static const double sectionGapTv = sectionGap * ShellTokens.tvChromeScale;
  static const double emptyIconSize = 48;
  static const double emptyIconSizeTv =
      emptyIconSize * ShellTokens.tvChromeScale;
  static const double headerIconSize = 24;
  static const double headerIconSizeTv =
      headerIconSize * ShellTokens.tvChromeScale;
  /// Extra beyond [headerIconSize] for the tappable hit box.
  static const double headerIconHitPad = 20;
  static const double headerIconHitPadTv =
      headerIconHitPad * ShellTokens.tvChromeScale;
  static const double searchPrefixIconSize = 20;
  static const double searchPrefixIconSizeTv =
      searchPrefixIconSize * ShellTokens.tvChromeScale;
  static const double searchFieldRadius = 10;
  static const double searchFieldRadiusTv =
      searchFieldRadius * ShellTokens.tvChromeScale;
  static const double rowLineGap = 6;
  static const double rowLineGapTv = rowLineGap * ShellTokens.tvChromeScale;
  static const double rowMetaGap = 3;
  static const double rowMetaGapTv = 2;
  static const double rowSeatsGap = 4;
  static const double rowSeatsGapTv = rowSeatsGap * ShellTokens.tvChromeScale;
  static const double probeCardWidth = 280;
  static const double probeCardWidthTv =
      probeCardWidth * ShellTokens.tvChromeScale;
  static const double probeCardRadius = 12;
  static const double probeCardRadiusTv =
      probeCardRadius * ShellTokens.tvChromeScale;
  /// Below this window width, skip the hover probe peek (no room beside the list).
  static const double probeDetailMinWindowWidth = 900;
  static const double probeDotSize = 8;
  static const double probeDotSizeTv = probeDotSize * ShellTokens.tvChromeScale;
  static const double probeGap = 8;
  static const double probeGapTv = probeGap * ShellTokens.tvChromeScale;
  static const double probeMetaGap = 6;
  static const double probeMetaGapTv = probeMetaGap * ShellTokens.tvChromeScale;
  static const double probeSectionGap = 10;
  static const double probeSectionGapTv =
      probeSectionGap * ShellTokens.tvChromeScale;
  static const double probeLineGap = 4;
  static const double probeLineGapTv = probeLineGap * ShellTokens.tvChromeScale;
  static const double probeLabelWidth = 68;
  static const double probeLabelWidthTv =
      probeLabelWidth * ShellTokens.tvChromeScale;

  static double rowHeightOf(bool tv) => tv ? rowHeightTv : rowHeight;
  static double actionWidthOf(bool tv) => tv ? actionWidthTv : actionWidth;
  static double statusSlotOf(bool tv) => tv ? statusSlotTv : statusSlot;
  static double rowPadHOf(bool tv) => tv ? rowPadHTv : rowPadH;
  static double rowPadVOf(bool tv) => tv ? rowPadVTv : rowPadV;
  static double rowIconSizeOf(bool tv) => tv ? rowIconSizeTv : rowIconSize;
  static double rowActionHitSizeOf(bool tv) =>
      tv ? rowActionHitSizeTv : rowActionHitSize;
  static double emptyIconSizeOf(bool tv) => tv ? emptyIconSizeTv : emptyIconSize;
  static double headerIconSizeOf(bool tv) =>
      tv ? headerIconSizeTv : headerIconSize;
  static double headerIconHitOf(bool tv) =>
      headerIconSizeOf(tv) + (tv ? headerIconHitPadTv : headerIconHitPad);
  static double searchPrefixIconSizeOf(bool tv) =>
      tv ? searchPrefixIconSizeTv : searchPrefixIconSize;
  static double searchFieldRadiusOf(bool tv) =>
      tv ? searchFieldRadiusTv : searchFieldRadius;
  static double panelPadOf(bool tv) => tv ? panelPadTv : panelPad;
  static double sectionGapOf(bool tv) => tv ? sectionGapTv : sectionGap;
  static double itemSpacingOf(bool tv) => tv ? itemSpacingTv : itemSpacing;
  static double rowLineGapOf(bool tv) => tv ? rowLineGapTv : rowLineGap;
  static double rowMetaGapOf(bool tv) => tv ? rowMetaGapTv : rowMetaGap;
  static double rowSeatsGapOf(bool tv) => tv ? rowSeatsGapTv : rowSeatsGap;

  /// Resolve list row height — TV ladder when density is on, even if the host
  /// still passes the desktop default (or an older TV constant).
  static double resolveRowHeight(bool tv, double requested) {
    if (!tv) return requested;
    if (requested == rowHeight || requested == rowHeightTv || requested <= 0) {
      return rowHeightTv;
    }
    return ShellTokens.chromeScale(requested, tv: true, min: rowHeightTv);
  }

  static double resolvePanelWidth(bool tv, double requested) {
    if (!tv) return requested;
    if (requested == ShellTokens.sidePanelWidth || requested <= 0) {
      return ShellTokens.sidePanelWidthTv;
    }
    return ShellTokens.chromeScale(
      requested,
      tv: true,
      min: ShellTokens.sidePanelWidthTv,
    );
  }
}
