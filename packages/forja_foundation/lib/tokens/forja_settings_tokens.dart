import 'package:flutter/material.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

/// Layout constants for the Settings category hub (RFC-033).
///
/// TV sizes are leanback literals (not desktop × iso-desktop 0.85).
abstract final class SettingsTokens {
  /// Below this width, use list → push instead of sidebar.
  static const double splitMinWidth = 900;

  static const double sidebarWidth = 260;
  static const double sidebarWidthTv = 180;
  static const double detailMaxWidth = 720;
  /// Flat green left-bar + ink fill (category rail and detail rows) — no card radius.
  static const double categoryTileRadius = 0;
  static const double groupRadius = 12;
  static const double rowMinHeight = 56;
  static const double rowMinHeightTv = 40;
  static const double groupSpacing = 24;
  static const double groupSpacingTv = 14;
  static const double pagePadding = 20;
  static const double pagePaddingTv = 12;
  static const double groupLabelSize = 11;
  static const double groupLabelSizeTv = 10;
  static const double categoryTitleSize = 15;
  static const double categoryTitleSizeTv = 11;
  static const double categoryIconSize = 22;
  static const double categoryIconSizeTv = 16;
  static const double pageTitleSize = 22;
  static const double pageTitleSizeTv = 14;
  /// Hub list / sidebar "Settings" title ([ShellTabHeader]).
  static const double hubTitleSize = 24;
  static const double hubTitleSizeTv = 14;

  /// Flat switch geometry — thumb is always a circle (never non-uniform scaled).
  static const double switchTrackWidth = 34;
  static const double switchTrackWidthTv = 24;
  static const double switchTrackHeight = 18;
  static const double switchTrackHeightTv = 12;
  static const double switchThumbSize = 12;
  static const double switchThumbSizeTv = 8;

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

  static double hubTitleSizeOf(BuildContext context) =>
      _tv(context) ? hubTitleSizeTv : hubTitleSize;

  static double switchTrackWidthOf(BuildContext context) =>
      _tv(context) ? switchTrackWidthTv : switchTrackWidth;

  static double switchTrackHeightOf(BuildContext context) =>
      _tv(context) ? switchTrackHeightTv : switchTrackHeight;

  static double switchThumbSizeOf(BuildContext context) =>
      _tv(context) ? switchThumbSizeTv : switchThumbSize;
}
