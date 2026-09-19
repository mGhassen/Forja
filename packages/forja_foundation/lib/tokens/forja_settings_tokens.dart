import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

/// Layout constants for the Settings category hub (RFC-033).
///
/// TV sizes = desktop × [ShellTokens.tvLayoutScale] (iso-desktop).
abstract final class SettingsTokens {
  static const double _s = ShellTokens.tvLayoutScale;

  /// Below this width, use list → push instead of sidebar.
  static const double splitMinWidth = 900;

  static const double sidebarWidth = 260;
  static const double sidebarWidthTv = sidebarWidth * _s;
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
  static const double groupLabelSize = 11;
  static const double groupLabelSizeTv = ShellTokens.tvMetaFontSize;
  static const double categoryTitleSize = 15;
  static const double categoryTitleSizeTv = ShellTokens.tvBodyFontSize;
  static const double categoryIconSize = 22;
  static const double categoryIconSizeTv = categoryIconSize * _s;
  static const double pageTitleSize = 22;
  static const double pageTitleSizeTv = ShellTokens.tvTitleFontSize;

  /// Flat on/off switch — desktop; TV = × [ShellTokens.tvLayoutScale].
  static const double switchTrackWidth = 36;
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

  static double categoryIconSizeOf(BuildContext context) =>
      _tv(context) ? categoryIconSizeTv : categoryIconSize;

  static double pageTitleSizeOf(BuildContext context) =>
      _tv(context) ? pageTitleSizeTv : pageTitleSize;

  static double switchTrackWidthOf(BuildContext context) =>
      _tv(context) ? switchTrackWidthTv : switchTrackWidth;

  static double switchTrackHeightOf(BuildContext context) =>
      _tv(context) ? switchTrackHeightTv : switchTrackHeight;

  static double switchThumbSizeOf(BuildContext context) =>
      _tv(context) ? switchThumbSizeTv : switchThumbSize;
}
