import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_theme_extension.dart';

/// Size scale for [Spinner].
enum SpinnerSize {
  sm,
  md,
  lg,
}

/// Indeterminate circular spinner.
class Spinner extends StatelessWidget {
  const Spinner({
    super.key,
    this.size = SpinnerSize.md,
    this.color,
    this.strokeWidth,
    this.dimension,
  });

  final SpinnerSize size;
  final Color? color;
  final double? strokeWidth;

  /// When set, overrides [size] pixel dimensions (TV chrome scale).
  final double? dimension;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final dim = dimension ??
        switch (size) {
          SpinnerSize.sm => 16.0,
          SpinnerSize.md => 24.0,
          SpinnerSize.lg => 36.0,
        };
    final stroke = strokeWidth ??
        switch (size) {
          SpinnerSize.sm => 2.0,
          SpinnerSize.md => 2.5,
          SpinnerSize.lg => 3.0,
        };
    return SizedBox(
      width: dim,
      height: dim,
      child: CircularProgressIndicator(
        strokeWidth: stroke,
        color: color ?? theme.brandGreen,
      ),
    );
  }
}
