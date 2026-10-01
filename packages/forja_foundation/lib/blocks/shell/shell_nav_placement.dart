import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Where the shell navbar sits for an app writing direction.
///
/// The host passes the Features setting. Pack pages keep their own
/// [Directionality]. This only places chrome (rail, content inset, compact
/// menu) on the start edge of [textDirection]: left for LTR, right for RTL.
class ShellNavPlacement {
  const ShellNavPlacement({this.textDirection = TextDirection.ltr});

  static const ltr = ShellNavPlacement();

  final TextDirection textDirection;

  bool get isRtl => textDirection == TextDirection.rtl;

  /// Rail occupies the physical right edge.
  bool get railOnRight => isRtl;

  /// Reserves [railWidth] on the rail edge and keeps the other safe inset.
  EdgeInsets contentPadding({
    required double railWidth,
    required double safeLeft,
    required double safeRight,
  }) {
    if (railOnRight) {
      return EdgeInsets.only(left: safeLeft, right: safeRight + railWidth);
    }
    return EdgeInsets.only(left: safeLeft + railWidth, right: safeRight);
  }

  /// Compact menu button inset on the rail edge.
  EdgeInsets compactMenuPadding({
    required double leading,
    required double top,
  }) {
    if (railOnRight) {
      return EdgeInsets.only(right: leading, top: top);
    }
    return EdgeInsets.only(left: leading, top: top);
  }

  /// D-pad arrow that leaves the rail and enters the page.
  bool isTowardPage(LogicalKeyboardKey key) =>
      key ==
      (isRtl ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight);

  /// D-pad arrow that points off the page (trapped on the rail).
  bool isAwayFromPage(LogicalKeyboardKey key) =>
      key ==
      (isRtl ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft);
}
