import 'package:flutter/material.dart' hide ListTile, Slider;
import 'package:forja_foundation/components/list_tile.dart';
import 'package:forja_foundation/components/slider.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';

/// Settings row chrome — props only (RFC-106 G8 pull-in).
///
/// Host wires state / navigation. Presentation only.
class SettingsRowChrome extends StatelessWidget {
  const SettingsRowChrome({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      leading: leading,
      trailing: trailing,
      onTap: onTap,
      density: dense ? ListTileDensity.dense : ListTileDensity.default_,
    );
  }
}

/// Player volume / seek slider chrome — props only (G8).
class PlayerSliderChrome extends StatelessWidget {
  const PlayerSliderChrome({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.label,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Padding(
            padding: EdgeInsets.only(bottom: theme.spaceSm / 2),
            child: Text(
              label!,
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
