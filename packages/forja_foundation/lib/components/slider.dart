import 'package:flutter/material.dart' hide Slider;
import 'package:flutter/material.dart' as material show Slider;
import 'package:forja_foundation/theme/forja_theme_extension.dart';

/// Size scale for [Slider].
enum SliderSize {
  sm,
  md,
}

/// Forja range slider — brand-green active track.
class Slider extends StatelessWidget {
  const Slider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.size = SliderSize.md,
    this.label,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;
  final SliderSize size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final trackHeight = size == SliderSize.sm ? 2.0 : 4.0;
    final thumb = size == SliderSize.sm ? 12.0 : 16.0;

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: theme.brandGreen,
        inactiveTrackColor: theme.borderSubtle,
        thumbColor: theme.textPrimary,
        overlayColor: theme.brandGreen.withValues(alpha: 0.12),
        trackHeight: trackHeight,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: thumb / 2),
      ),
      child: material.Slider(
        value: value.clamp(min, max),
        onChanged: onChanged,
        min: min,
        max: max,
        divisions: divisions,
        label: label,
      ),
    );
  }
}
