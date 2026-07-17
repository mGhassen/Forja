import 'package:flutter/material.dart';
import 'package:forja/shared/design/src/forja_shell_colors.dart';

/// Shared Forja toggle — brand-green track, elevated thumb, hairline off outline.
///
/// Prefer this over raw [Switch] / [SwitchListTile] color overrides. App theme
/// [forjaSwitchThemeData] mirrors the same tokens so Material list tiles inherit
/// the look when they do not override colors.
class ForjaSwitch extends StatelessWidget {
  const ForjaSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.scale = 1.0,
  });

  /// Compact scale used by settings toggle rows.
  static const double settingsScale = 0.82;

  final bool value;
  final ValueChanged<bool>? onChanged;

  /// Visual scale (e.g. [settingsScale] in dense settings lists).
  final double scale;

  @override
  Widget build(BuildContext context) {
    final child = Switch(
      value: value,
      onChanged: onChanged,
      thumbColor: forjaSwitchThumbColor,
      trackColor: forjaSwitchTrackColor,
      trackOutlineColor: forjaSwitchTrackOutlineColor,
      overlayColor: forjaSwitchOverlayColor,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    if ((scale - 1.0).abs() < 0.001) return child;
    return Transform.scale(scale: scale, child: child);
  }
}

/// Theme data matching [ForjaSwitch] — set on [ThemeData.switchTheme].
SwitchThemeData get forjaSwitchThemeData => SwitchThemeData(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      thumbColor: forjaSwitchThumbColor,
      trackColor: forjaSwitchTrackColor,
      trackOutlineColor: forjaSwitchTrackOutlineColor,
      overlayColor: forjaSwitchOverlayColor,
    );

final WidgetStateProperty<Color?> forjaSwitchThumbColor =
    WidgetStateProperty.resolveWith((states) {
  if (states.contains(WidgetState.hovered) ||
      states.contains(WidgetState.focused) ||
      states.contains(WidgetState.pressed)) {
    return Colors.white;
  }
  return ForjaShellColors.surfaceElevated;
});

final WidgetStateProperty<Color?> forjaSwitchTrackColor =
    WidgetStateProperty.resolveWith((states) {
  if (states.contains(WidgetState.selected)) {
    return ForjaShellColors.brandGreen;
  }
  return const Color(0xFF3A3A3A);
});

final WidgetStateProperty<Color?> forjaSwitchTrackOutlineColor =
    WidgetStateProperty.resolveWith((states) {
  if (states.contains(WidgetState.selected)) {
    return Colors.transparent;
  }
  return ForjaShellColors.borderSubtle;
});

final WidgetStateProperty<Color?> forjaSwitchOverlayColor =
    WidgetStateProperty.resolveWith((states) {
  if (states.contains(WidgetState.hovered) ||
      states.contains(WidgetState.focused)) {
    return ForjaShellColors.textPrimary.withValues(alpha: 0.08);
  }
  return Colors.transparent;
});
