import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/tokens/forja_theme_extension.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

/// Labeled field shell — label + child + optional error.
class Field extends StatelessWidget {
  const Field({
    super.key,
    this.label,
    required this.child,
    this.error,
    this.isRequired = false,
  });

  final String? label;
  final Widget child;
  final String? error;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final labelSize = ShellPaintScope.usesTvDensityOf(context)
        ? ShellTokens.formInputLabelFontSizeTv
        : ShellTokens.formInputLabelFontSize;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Row(
            children: [
              Flexible(
                child: Text(
                  label!,
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: labelSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isRequired)
                Text(
                  ' *',
                  style: TextStyle(
                    color: theme.brandGreen,
                    fontSize: labelSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          SizedBox(height: theme.spaceSm),
        ],
        child,
        if (error != null && error!.isNotEmpty) ...[
          SizedBox(height: theme.spaceSm),
          Text(
            error!,
            style: TextStyle(
              color: const Color(0xFFF87171),
              fontSize: labelSize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
