import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

/// Layout constants for the Settings category hub (RFC-033).
///
/// Spatial chrome (pads, icons, switches) follows [ShellTokens.tvChromeScale].
/// Type roles map onto the shell ladder — never invent a parallel Settings scale:
///
/// | Role | Desktop | TV |
/// |---|---|---|
/// | Hub / page title | [hubTitleSize] / [pageTitleSize] | [ShellTokens.tvTitleFontSize] |
/// | Category / row title | [categoryTitleSize] / [rowTitleSize] | [ShellTokens.tvBodyFontSize] |
/// | Subtitle / group label | [categorySubtitleSize] / … | [ShellTokens.tvMetaFontSize] |
abstract final class SettingsTokens {
  /// Below this width, use list → push instead of sidebar.
  static const double splitMinWidth = 900;

  static const double _s = ShellTokens.tvChromeScale;

  /// Category rail — wide enough for title + subtitle without heavy ellipsis.
  static const double sidebarWidth = 340;

  /// Leanback — hand width so labels stay readable (not × [tvChromeScale]).
  static const double sidebarWidthTv = 240;
  static const double detailMaxWidth = 720;

  /// Flat green left-bar + ink fill (category rail and detail rows) — no card radius.
  static const double categoryTileRadius = 0;
  static const double groupRadius = 12;
  static const double rowMinHeight = 56;
  static const double rowMinHeightTv = rowMinHeight * _s;
  static const double groupSpacing = 24;
  static const double groupSpacingTv = groupSpacing * _s;
  static const double pagePadding = 20;
  static const double pagePaddingTv = pagePadding * _s;

  // --- Type roles → shell ladder on TV ---
  static const double groupLabelSize = 11;
  static const double groupLabelSizeTv = ShellTokens.tvMetaFontSize;
  static const double categoryTitleSize = 15;
  static const double categoryTitleSizeTv = ShellTokens.tvBodyFontSize;
  static const double categorySubtitleSize = 12;
  static const double categorySubtitleSizeTv = ShellTokens.tvMetaFontSize;
  static const double categoryIconSize = 22;
  static const double categoryIconSizeTv = categoryIconSize * _s;
  static const double pageTitleSize = 22;
  static const double pageTitleSizeTv = ShellTokens.tvTitleFontSize;

  /// Hub list / sidebar "Settings" title ([ShellTabHeader]).
  static const double hubTitleSize = 24;
  static const double hubTitleSizeTv = ShellTokens.tvTitleFontSize;

  /// Detail row title / subtitle (toggle, link, select rows).
  static const double rowTitleSize = 15;
  static const double rowTitleSizeTv = ShellTokens.tvBodyFontSize;
  static const double rowSubtitleSize = 12.5;
  static const double rowSubtitleSizeTv = ShellTokens.tvMetaFontSize;

  /// Flat switch geometry — thumb is always a circle (never non-uniform scaled).
  static const double switchTrackWidth = 34;
  static const double switchTrackWidthTv = switchTrackWidth * _s;
  static const double switchTrackHeight = 18;
  static const double switchTrackHeightTv = switchTrackHeight * _s;
  static const double switchThumbSize = 12;
  static const double switchThumbSizeTv = switchThumbSize * _s;

  /// True when Settings should show the split sidebar layout.
  /// Desktop / wide and Android TV (1080p+) use the same hub chrome.
  static bool useSplitLayout(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= splitMinWidth;
  }

  static bool _tv(BuildContext context) =>
      ShellPaintScope.usesTvDensityOf(context);

  static double sidebarWidthOf(BuildContext context) =>
      _tv(context) ? sidebarWidthTv : sidebarWidth;

  static double rowMinHeightOf(BuildContext context) =>
      _tv(context) ? rowMinHeightTv : rowMinHeight;

  static double groupSpacingOf(BuildContext context) =>
      _tv(context) ? groupSpacingTv : groupSpacing;

  static double pagePaddingOf(BuildContext context) =>
      _tv(context) ? pagePaddingTv : pagePadding;

  static double groupLabelSizeOf(BuildContext context) =>
      _tv(context) ? groupLabelSizeTv : groupLabelSize;

  static double categoryTitleSizeOf(BuildContext context) =>
      _tv(context) ? categoryTitleSizeTv : categoryTitleSize;

  static double categorySubtitleSizeOf(BuildContext context) =>
      _tv(context) ? categorySubtitleSizeTv : categorySubtitleSize;

  static double categoryIconSizeOf(BuildContext context) =>
      _tv(context) ? categoryIconSizeTv : categoryIconSize;

  static double pageTitleSizeOf(BuildContext context) =>
      _tv(context) ? pageTitleSizeTv : pageTitleSize;

  static double hubTitleSizeOf(BuildContext context) =>
      _tv(context) ? hubTitleSizeTv : hubTitleSize;

  static double rowTitleSizeOf(BuildContext context) =>
      _tv(context) ? rowTitleSizeTv : rowTitleSize;

  static double rowSubtitleSizeOf(BuildContext context) =>
      _tv(context) ? rowSubtitleSizeTv : rowSubtitleSize;

  static double switchTrackWidthOf(BuildContext context) =>
      _tv(context) ? switchTrackWidthTv : switchTrackWidth;

  static double switchTrackHeightOf(BuildContext context) =>
      _tv(context) ? switchTrackHeightTv : switchTrackHeight;

  static double switchThumbSizeOf(BuildContext context) =>
      _tv(context) ? switchThumbSizeTv : switchThumbSize;
}
