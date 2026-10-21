/// Flat gradient scrim behind an overlay top menu (hub chrome) while catalog
/// content can scroll under it. Paint-only numbers — no blur, no glow.
abstract final class TopBarScrimTokens {
  /// Scrim alpha at the top edge (menu label band).
  static const double topAlpha = 0.88;

  /// Alpha at [midStop] — keeps the label row legible, then fades out.
  static const double midAlpha = 0.55;

  /// Gradient stop (0…1 of scrim height) where [midAlpha] applies.
  static const double midStop = 0.55;

  /// Scrim height as a multiple of the bar height so the tail fades past the
  /// menu underline instead of ending on a hard edge.
  static const double heightFactor = 1.6;

  /// Scroll distance (px) over which the scrim fades in from rest. An
  /// unscrolled hero already insets its text under the bar — no scrim at rest.
  static const double scrollFadeInDistance = 56;
}
