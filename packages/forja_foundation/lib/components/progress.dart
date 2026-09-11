import 'package:flutter/material.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Progress indicator — linear or circular.
enum ProgressVariant {
  linear,
  circular,
}

/// Determinate / indeterminate progress.
class Progress extends StatelessWidget {
  const Progress({
    super.key,
    this.value,
    this.variant = ProgressVariant.linear,
    this.size = 24,
    this.strokeWidth = 2.5,
    this.color,
  });

  /// 0..1 for determinate; null for indeterminate.
  final double? value;
  final ProgressVariant variant;
  final double size;
  final double strokeWidth;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final c = color ?? ForjaShellColors.progressFill;
    if (variant == ProgressVariant.circular) {
      return SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          value: value,
          strokeWidth: strokeWidth,
          color: c,
          backgroundColor: theme.borderSubtle,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value,
        minHeight: strokeWidth + 1,
        color: c,
        backgroundColor: theme.borderSubtle,
      ),
    );
  }
}
