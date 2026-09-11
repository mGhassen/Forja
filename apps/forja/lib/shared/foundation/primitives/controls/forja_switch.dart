import 'package:flutter/material.dart';
import 'package:forja_foundation/components/switch.dart' as ds;

/// Shared Forja toggle — delegates to package [ds.Switch] (RFC-106).
///
/// Prefer this over raw Material [Switch] / [SwitchListTile] color overrides.
/// App theme [forjaSwitchThemeData] mirrors the same tokens.
class ForjaSwitch extends StatelessWidget {
  const ForjaSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.scale = 1.0,
    this.emphasized = false,
  });

  /// Compact scale used by settings toggle rows.
  static const double settingsScale = ds.Switch.settingsScale;

  final bool value;
  final ValueChanged<bool>? onChanged;
  final double scale;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return ds.Switch(
      value: value,
      onChanged: onChanged,
      scale: scale,
      emphasized: emphasized,
    );
  }
}

/// Theme data matching [ForjaSwitch] — set on [ThemeData.switchTheme].
SwitchThemeData get forjaSwitchThemeData => ds.forjaSwitchThemeData;

WidgetStateProperty<Color?> get forjaSwitchThumbColor =>
    ds.forjaSwitchThumbColor;

WidgetStateProperty<Color?> get forjaSwitchTrackColor =>
    ds.forjaSwitchTrackColor;

WidgetStateProperty<Color?> get forjaSwitchTrackOutlineColor =>
    ds.forjaSwitchTrackOutlineColor;

WidgetStateProperty<Color?> get forjaSwitchOverlayColor =>
    ds.forjaSwitchOverlayColor;
