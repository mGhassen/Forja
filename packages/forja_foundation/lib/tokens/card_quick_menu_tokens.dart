import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Tokens for the catalog card quick menu (`CardQuickMenu`): the OK-hold /
/// MENU-key flyout anchored beside a focused poster card.
///
/// Hold timing is passed explicitly to `InteractivePosterCard.longPressDuration`
/// by the quick-menu wire so a hold on a card and a hold on a nav item feel
/// the same; other long-press consumers keep their own timing. Sizes follow the chrome density family
/// ([ShellTokens.tvChromeScale]); type uses the leanback ladder.
abstract final class CardQuickMenuTokens {
  static const double _s = ShellTokens.tvChromeScale;

  /// OK held this long on a focused card opens the quick menu instead of
  /// activating the card. Same threshold as the nav rail provider hold.
  static const Duration holdDelay = Duration(milliseconds: 500);

  static const double minWidth = 200;
  static const double minWidthTv = 168;
  static const double maxWidth = 300;
  static const double maxWidthTv = 240;

  static const double radius = 10;
  static const double radiusTv = 8;

  /// Column inset above the first / below the last row.
  static const double padV = 6;
  static const double padVTv = padV * _s;

  static const double rowPadH = 14;
  static const double rowPadHTv = rowPadH * _s;
  static const double rowPadV = 10;
  static const double rowPadVTv = rowPadV * _s;

  static const double iconSize = 18;
  static const double iconSizeTv = iconSize * _s;

  /// Icon → label gap inside a row.
  static const double gap = 10;
  static const double gapTv = gap * _s;

  static const double labelFontSize = 13;
  static const double labelFontSizeTv = ShellTokens.tvBodyFontSize;

  /// Optional title line (card name) above the actions.
  static const double titleFontSize = 12;
  static const double titleFontSizeTv = ShellTokens.tvMetaFontSize;
  static const double titlePadB = 4;
  static const double titlePadBTv = titlePadB * _s;
  static const int titleMaxLines = 1;

  /// Gap between the anchor card edge and the menu.
  static const double anchorGap = 12;
  static const double anchorGapTv = anchorGap * _s;

  /// Menu never sits closer than this to the screen edge.
  static const double screenMargin = 24;
  static const double screenMarginTv = screenMargin * _s;

  static const double surfaceAlpha = 0.94;
  static const double borderAlpha = 0.12;
  static const double shadowAlpha = 0.45;
  static const double shadowBlur = 18;
  static const double shadowOffsetY = 8;

  /// Hover / D-pad row tint.
  static const double activeFillAlpha = 0.12;

  /// Full-screen scrim behind the menu (flat tint — no blur).
  static const double scrimAlpha = 0.35;

  /// Touch: long-press opens the same actions in a bottom sheet.
  static const double sheetRowHeight = 52;
  static const double sheetPadH = 20;
  static const double sheetPadB = 8;
  static const double sheetIconSize = 22;
  static const double sheetGap = 16;
  static const double sheetLabelFontSize = 15;
  static const double sheetTitleFontSize = 13;
  static const double sheetTitlePadB = 4;

  static double minWidthOf(bool tv) => tv ? minWidthTv : minWidth;
  static double maxWidthOf(bool tv) => tv ? maxWidthTv : maxWidth;
  static double radiusOf(bool tv) => tv ? radiusTv : radius;
  static double padVOf(bool tv) => tv ? padVTv : padV;
  static double rowPadHOf(bool tv) => tv ? rowPadHTv : rowPadH;
  static double rowPadVOf(bool tv) => tv ? rowPadVTv : rowPadV;
  static double iconSizeOf(bool tv) => tv ? iconSizeTv : iconSize;
  static double gapOf(bool tv) => tv ? gapTv : gap;
  static double labelFontSizeOf(bool tv) =>
      tv ? labelFontSizeTv : labelFontSize;
  static double titleFontSizeOf(bool tv) =>
      tv ? titleFontSizeTv : titleFontSize;
  static double titlePadBOf(bool tv) => tv ? titlePadBTv : titlePadB;
  static double anchorGapOf(bool tv) => tv ? anchorGapTv : anchorGap;
  static double screenMarginOf(bool tv) => tv ? screenMarginTv : screenMargin;
}
