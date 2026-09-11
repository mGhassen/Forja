import 'package:flutter/material.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';

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
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isRequired)
                Text(
                  ' *',
                  style: TextStyle(
                    color: theme.brandGreen,
                    fontSize: 12,
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
            style: const TextStyle(
              color: Color(0xFFF87171),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
