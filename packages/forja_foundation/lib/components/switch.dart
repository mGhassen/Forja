import 'package:flutter/material.dart' hide Switch;
import 'package:flutter/material.dart' as material show Switch;
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Forja on/off switch — brand-green track, elevated thumb.
class Switch extends StatelessWidget {
  const Switch({
    super.key,
    required this.value,
    required this.onChanged,
    this.scale = 1.0,
    this.emphasized = false,
  });

  /// Compact scale for dense settings rows.
  static const double settingsScale = 0.82;

  final bool value;
  final ValueChanged<bool>? onChanged;
  final double scale;

  /// Force white thumb (when outer wrapper owns hover/focus).
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final child = material.Switch(
      value: value,
      onChanged: onChanged,
      thumbColor: emphasized
          ? const WidgetStatePropertyAll(Colors.white)
          : forjaSwitchThumbColor,
      trackColor: forjaSwitchTrackColor,
      trackOutlineColor: forjaSwitchTrackOutlineColor,
      overlayColor: forjaSwitchOverlayColor,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    if ((scale - 1.0).abs() < 0.001) return child;
    return Transform.scale(scale: scale, child: child);
  }
}

/// Theme data matching [Switch] — set on [ThemeData.switchTheme].
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

const WidgetStateProperty<Color?> forjaSwitchOverlayColor =
    WidgetStatePropertyAll<Color?>(Colors.transparent);
