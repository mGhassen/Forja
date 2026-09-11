import 'package:flutter/material.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';

/// Form / section label text.
class Label extends StatelessWidget {
  const Label({
    super.key,
    required this.text,
    this.isRequired = false,
    this.size = LabelSize.md,
  });

  final String text;
  final bool isRequired;
  final LabelSize size;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final fontSize = switch (size) {
      LabelSize.sm => 11.0,
      LabelSize.md => 12.0,
      LabelSize.lg => 14.0,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        if (isRequired)
          Text(
            ' *',
            style: TextStyle(
              color: theme.brandGreen,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

/// Size scale for [Label].
enum LabelSize {
  sm,
  md,
  lg,
}
