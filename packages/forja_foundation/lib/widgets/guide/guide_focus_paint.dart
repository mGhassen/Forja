import 'package:flutter/material.dart';

import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/guide/guide_chrome_style.dart';

/// Idle tint → brand green on TV focus, white on hover (matches player chrome).
Color guideFocusFg(
  Color idle, {
  required bool active,
  required bool tvFocused,
}) {
  if (tvFocused) return ForjaShellColors.brandGreen;
  if (active) return Colors.white;
  return idle;
}

Color guideFocusSurfaceColor({
  required bool active,
  required bool tvFocused,
  double idleAlpha = 0.08,
  double hoverAlpha = 0.14,
  bool subtle = false,
}) {
  if (tvFocused) return ForjaShellColors.brandGreen.withValues(alpha: 0.14);
  if (active) return Colors.white.withValues(alpha: subtle ? 0.14 : hoverAlpha);
  return Colors.white.withValues(alpha: idleAlpha);
}

Color guideFocusOutlineColor({
  required bool active,
  required bool tvFocused,
  double idleAlpha = 0.12,
  double hoverAlpha = 0.22,
  Color? idleOverride,
}) {
  if (tvFocused) return ForjaShellColors.brandGreen;
  if (active) return Colors.white.withValues(alpha: hoverAlpha);
  return idleOverride ?? Colors.white.withValues(alpha: idleAlpha);
}

/// Button/chip surface when D-pad focused - matches player chrome controls.
BoxDecoration guideFocusButtonDecoration({
  required bool active,
  required bool tvFocused,
  required double borderRadius,
  Color? idleBg,
  Color? idleBorder,
  bool subtle = false,
}) {
  final radius = BorderRadius.circular(borderRadius);
  if (tvFocused) {
    return BoxDecoration(
      color: ForjaShellColors.brandGreen.withValues(alpha: 0.14),
      borderRadius: radius,
      border: Border.all(color: ForjaShellColors.brandGreen, width: 1.5),
    );
  }
  if (!active) {
    return BoxDecoration(
      color: idleBg ??
          (subtle
              ? GuideChromeStyle.surfaceMuted
              : GuideChromeStyle.chipSelectedBg),
      borderRadius: radius,
      border: Border.all(
        color: idleBorder ??
            (subtle
                ? Colors.white.withValues(alpha: 0.15)
                : GuideChromeStyle.chipSelectedBorder),
      ),
    );
  }
  return BoxDecoration(
    color: Colors.white.withValues(alpha: subtle ? 0.14 : 0.18),
    borderRadius: radius,
    border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
  );
}

/// Border colors for share-code cells (boxed OTP style).
Color guideDialogFieldBorderColor({required bool focused}) =>
    Colors.white.withValues(alpha: focused ? 0.35 : 0.12);

/// Underline field chrome for portal URL / username / password.
InputDecoration guideDialogFieldDecoration({
  required bool focused,
  String? hintText,
  TextStyle? hintStyle,
  Widget? suffixIcon,
}) {
  final idle = BorderSide(
    color: Colors.white.withValues(alpha: 0.16),
  );
  final active = BorderSide(
    color: focused
        ? ForjaShellColors.brandGreen
        : Colors.white.withValues(alpha: 0.4),
    width: focused ? 1.5 : 1,
  );
  return InputDecoration(
    hintText: hintText,
    hintStyle: hintStyle,
    isDense: true,
    filled: false,
    contentPadding: const EdgeInsets.fromLTRB(0, 6, 0, 10),
    suffixIcon: suffixIcon,
    suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 32),
    border: UnderlineInputBorder(borderSide: idle),
    enabledBorder: UnderlineInputBorder(borderSide: idle),
    focusedBorder: UnderlineInputBorder(borderSide: active),
    disabledBorder: UnderlineInputBorder(borderSide: idle),
  );
}
