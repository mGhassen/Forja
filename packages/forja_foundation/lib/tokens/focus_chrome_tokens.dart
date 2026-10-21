import 'package:flutter/painting.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// One leanback (D-pad) focus signature for every surface: an accent ring
/// that follows the control's corner radius, a soft accent glow, and a lift
/// per control family. Chrome snaps on leanback (`instantFocusChrome`).
///
/// Desktop keeps its own hover / keyboard look — those numbers live here too
/// ([hoverRingColor], [hoverRingWidth], [flatRingAlpha]) so no paint file
/// re-hardcodes them.
abstract final class FocusChromeTokens {
  // ---------------------------------------------------------------- leanback

  /// Ring + glow + backplate color — the brand accent.
  static const Color ringColor = ForjaShellColors.brandGreen;

  /// Ring stroke. Painted inside the control box (never changes layout).
  static const double ringWidth = 2;

  /// Glow behind the ring (BoxShadow, no blur filter).
  static const double glowBlur = 12;
  static const double glowSpread = 0;
  static const double glowAlpha = 0.45;

  /// Lift per family. Cards keep the catalog scale; chips, mood circles and
  /// text tabs lift less; list rows do not move.
  static const double cardScale = ShellTokens.focusActiveScale;

  /// Same as `ForjaMotionTheme.defaults.chipLift.focusScale`.
  static const double chipScale = 1.04;
  static const double rowScale = 1.0;

  /// Accent fill behind a focused nav icon / chip face.
  static const double backplateAlpha = 0.16;

  /// Lighter accent fill behind a ringed flat row (settings detail buttons).
  static const double tintAlpha = 0.10;

  /// Settings rows: leading accent bar kept beside the ring.
  static const double railAccentWidth = 2.5;

  /// Pill drawn around top-menu tab text (outside the text box, paint only).
  static const double textPillInsetH = 10;
  static const double textPillInsetV = 4;
  static const double textPillRadius = 8;

  /// Backplate drawn around a nav rail icon box (outside the box, paint only).
  /// No bottom inset: the selected-tab underline sits right under the box.
  static const double railBackplateInset = 4;
  static const double railBackplateInsetBottom = 0;
  static const double railBackplateRadius = 10;

  /// Chrome tween: zero on leanback, [hoverTween] elsewhere.
  static const Duration leanbackTween = Duration.zero;

  // ----------------------------------------------------------------- desktop

  /// Desktop keyboard-focus ring on cards (unchanged look).
  static const Color hoverRingColor = Color(0xFFFFFFFF);
  static const double hoverRingWidth = ShellTokens.cardFocusBorderWidth;

  /// Desktop flat menu ring / fill (gray hairline, faint ink).
  static const double flatRingAlpha = 0.28;
  static const double flatRingWidth = 1;
  static const double flatFillAlpha = 0.08;
  static const Duration hoverTween = Duration(milliseconds: 140);

  // ----------------------------------------------------------------- helpers

  static Color glowColor() => ringColor.withValues(alpha: glowAlpha);

  static Color backplateFill() => ringColor.withValues(alpha: backplateAlpha);

  static Color tintFill() => ringColor.withValues(alpha: tintAlpha);

  static List<BoxShadow> glow() => [
    BoxShadow(
      color: glowColor(),
      blurRadius: glowBlur,
      spreadRadius: glowSpread,
    ),
  ];

  static BorderSide ringSide() =>
      const BorderSide(color: ringColor, width: ringWidth);

  /// Ring (+ optional glow / fill) that follows [borderRadius], or a circle.
  static BoxDecoration ring({
    BorderRadius? borderRadius,
    BoxShape shape = BoxShape.rectangle,
    Color? fill,
    bool withGlow = true,
  }) {
    return BoxDecoration(
      shape: shape,
      borderRadius: shape == BoxShape.circle ? null : borderRadius,
      color: fill,
      border: Border.all(color: ringColor, width: ringWidth),
      boxShadow: withGlow ? glow() : null,
    );
  }

  /// Desktop keyboard-focus ring on a card (white hairline, no glow).
  static BoxDecoration hoverRing({required BorderRadius borderRadius}) {
    return BoxDecoration(
      borderRadius: borderRadius,
      border: Border.all(color: hoverRingColor, width: hoverRingWidth),
    );
  }

  /// Desktop flat-menu ring (gray hairline, optional faint fill).
  static BoxDecoration flatRing({
    required BorderRadius borderRadius,
    required bool withFill,
  }) {
    return BoxDecoration(
      color: withFill
          ? hoverRingColor.withValues(alpha: flatFillAlpha)
          : const Color(0x00000000),
      borderRadius: borderRadius,
      border: Border.all(
        color: hoverRingColor.withValues(alpha: flatRingAlpha),
        width: flatRingWidth,
      ),
    );
  }
}
