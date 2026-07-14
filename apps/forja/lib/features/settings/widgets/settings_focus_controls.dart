import 'package:flutter/material.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';

/// TV-aware toggle row for settings sections (RFC-033 primitives).
Widget settingsFocusableToggle(
  BuildContext context,
  String title,
  String subtitle,
  bool value,
  ValueChanged<bool> onChanged,
) {
  return SettingsToggleRow(
    title: title,
    subtitle: subtitle,
    value: value,
    onChanged: onChanged,
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
