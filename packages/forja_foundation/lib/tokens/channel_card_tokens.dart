/// Layout tokens for IPTV channel catalog cards.
abstract final class ChannelCardTokens {
  static const double radius = 12;
  static const double epgSlotHeight = 22;

  /// Fixed title strip under the logo — keeps the logo [Expanded] slot stable
  /// regardless of title length (never let text steal logo height).
  static const double titleBarHeight = 36;
  static const double titleBarPadH = 8;
  static const double cardTitleFontSize = 12;

  /// EPG sheet / meta type.
  static const double titleFontSize = 14;
  static const double metaFontSize = 11;
  static const double badgeFontSize = 8;

  /// Inset around [BoxFit.contain] logos inside the fixed logo slot.
  static const double logoPad = 10;
}
