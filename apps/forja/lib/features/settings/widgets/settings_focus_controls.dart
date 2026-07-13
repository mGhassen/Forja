import 'package:flutter/material.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';

/// TV-aware toggle row for settings sections.
Widget settingsFocusableToggle(
  BuildContext context,
  String title,
  String subtitle,
  bool value,
  ValueChanged<bool> onChanged,
) {
  final content = Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 13, color: Colors.white54),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: AppTheme.current.primaryColor,
        ),
      ],
    ),
  );
  return shellFocusableTap(
    context: context,
    onTap: () => onChanged(!value),
    scaleOnFocus: 1.0,
    navLeftAlways: true,
    tvTabId: 'settings',
    tvZone: ShellTvZone.settings,
    child: content,
  );
}

/// TV-aware dropdown row for settings sections.
Widget settingsFocusableDropdown(
  BuildContext context,
  String title,
  String subtitle,
  String value,
  List<String> options,
  ValueChanged<String?> onChanged,
) {
  final content = Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 13, color: Colors.white54),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButton<String>(
            value: value,
            dropdownColor: Color.lerp(
              AppTheme.current.bgDark,
              AppTheme.current.primaryColor,
              0.08,
            ),
            underline: const SizedBox.shrink(),
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppTheme.current.primaryColor,
            ),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            selectedItemBuilder: (BuildContext context) {
              return options.map<Widget>((String item) {
                return Container(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList();
            },
            items: options
                .map(
                  (o) => DropdownMenuItem(
                    value: o,
                    child: Text(
                      o,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    ),
  );
  return shellFocusableTap(
    context: context,
    onTap: () {},
    scaleOnFocus: 1.0,
    navLeftAlways: true,
    tvTabId: 'settings',
    tvZone: ShellTvZone.settings,
    child: content,
  );
}
