import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Layout tokens for IPTV channel catalog cards.
///
/// TV sizes are **hand-tuned** (logo face at 10ft) — not
/// [ShellTokens.tvChromeScale]. See density families on [ShellTokens].
abstract final class ChannelCardTokens {
  static const double radius = 12;
  static const double radiusTv = 10;
  static const double epgSlotHeight = 22;
  static const double epgSlotHeightTv = 18;

  /// Fixed title strip under the logo — keeps the logo band height stable.
  static const double titleBarHeight = 36;
  static const double titleBarHeightTv = 26;
  static const double titleBarPadH = 8;
  static const double titleBarPadHTv = 6;
  static const double cardTitleFontSize = 12;
  static const double cardTitleFontSizeTv = ShellTokens.tvBodyFontSize;

  /// EPG sheet / meta type.
  static const double titleFontSize = 14;
  static const double titleFontSizeTv = ShellTokens.tvTitleFontSize;
  static const double metaFontSize = 11;
  static const double metaFontSizeTv = ShellTokens.tvMetaFontSize;
  static const double badgeFontSize = 8;
  static const double badgeFontSizeTv = ShellTokens.tvMetaFontSize;

  /// Inset for [BoxFit.contain] logos inside the full logo band (card face).
  static const double logoPad = 10;
  static const double logoPadTv = 8;

  /// Leanback channel tile width — hand-tuned logo face (denser than film posters).
  /// Keep in sync with [ShellTokens.channelCardWidthTv].
  static const double widthTv = ShellTokens.channelCardWidthTv;

  static double radiusOf(bool tv) => tv ? radiusTv : radius;
  static double titleBarHeightOf(bool tv) =>
      tv ? titleBarHeightTv : titleBarHeight;
  static double titleBarPadHOf(bool tv) => tv ? titleBarPadHTv : titleBarPadH;
  static double cardTitleFontSizeOf(bool tv) =>
      tv ? cardTitleFontSizeTv : cardTitleFontSize;
  static double titleFontSizeOf(bool tv) => tv ? titleFontSizeTv : titleFontSize;
  static double metaFontSizeOf(bool tv) => tv ? metaFontSizeTv : metaFontSize;
  static double badgeFontSizeOf(bool tv) => tv ? badgeFontSizeTv : badgeFontSize;
  static double epgSlotHeightOf(bool tv) =>
      tv ? epgSlotHeightTv : epgSlotHeight;
  static double logoPadOf(bool tv) => tv ? logoPadTv : logoPad;
}
