/// Layout tokens for live event cards.
abstract final class EventCardTokens {
  static const double radius = 14;
  static const double titleFontSize = 12;
  static const double metaFontSize = 10;
  static const double badgeFontSize = 8.5;
  static const double playIconSize = 28;
  static const double playIconSizeTv = 16;
  static const double playOverlaySize = 48;
  static const double padV = 8;

  /// Desktop grid min width = continue-watching wide × this.
  static const double desktopWidthScale = 0.85;

  /// Desktop grid min height = continue-watching wide × this.
  static const double desktopHeightScale = 1.0;

  static const double desktopHeightMin = 130;
  static const double desktopHeightMax = 165;

  /// Extra height on TV for title/schedule caption under the visual.
  static const double tvCaptionExtra = 40;
  static const double tvCaptionExtraMin = 32;
  static const double tvCaptionExtraMax = 48;

  /// Kit paint fallback when props omit width/height.
  static const double paintFallbackWidth = 220;
  static const double paintFallbackHeight = 124;
}
