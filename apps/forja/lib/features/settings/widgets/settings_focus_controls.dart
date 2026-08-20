import 'package:flutter/material.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';

/// TV-aware toggle row for settings sections (RFC-033 primitives).
Widget settingsFocusableToggle(
  BuildContext context,
  String title,
  String subtitle,
  bool value,
  ValueChanged<bool> onChanged, {
  bool enabled = true,
  bool adminOnly = false,
  bool? leadingCheckValue,
  ValueChanged<bool>? onLeadingCheckChanged,
  String leadingCheckLabel = 'Auto',
}) {
  return SettingsToggleRow(
    title: title,
    subtitle: subtitle,
    value: value,
    onChanged: onChanged,
    enabled: enabled,
    adminOnly: adminOnly,
    leadingCheckValue: leadingCheckValue,
    onLeadingCheckChanged: onLeadingCheckChanged,
    leadingCheckLabel: leadingCheckLabel,
  );
}

/// TV-aware dropdown row for settings sections (RFC-033 primitives).
Widget settingsFocusableDropdown(
  BuildContext context,
  String title,
  String subtitle,
  String value,
  List<String> options,
  ValueChanged<String?> onChanged,
) {
  return SettingsSelectRow(
    title: title,
    subtitle: subtitle,
    value: value,
    options: options,
    onChanged: onChanged,
  );
}

/// TV-aware slider - ←/→ nudge while focused (no OK arm).
Widget settingsFocusableSlider({
  required String title,
  String? subtitle,
  required double value,
  required double min,
  required double max,
  required String label,
  required ValueChanged<double> onChanged,
  ValueChanged<double>? onChangeEnd,
  int? divisions,
}) {
  return SettingsSliderRow(
    title: title,
    subtitle: subtitle,
    value: value,
    min: min,
    max: max,
    label: label,
    onChanged: onChanged,
    onChangeEnd: onChangeEnd,
    divisions: divisions,
  );
}
