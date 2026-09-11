import 'package:flutter/material.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';

/// Size scale for [Empty].
enum EmptySize {
  sm,
  md,
  lg,
}

/// Empty-state placeholder — icon / title / description / action slot.
class Empty extends StatelessWidget {
  const Empty({
    super.key,
    this.title,
    this.description,
    this.icon,
    this.action,
    this.size = EmptySize.md,
  });

  final String? title;
  final String? description;
  final IconData? icon;
  final Widget? action;
  final EmptySize size;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final dims = _dims(size);

    return Center(
      child: Padding(
        padding: EdgeInsets.all(theme.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: dims.iconSize, color: theme.textSecondary),
              SizedBox(height: theme.spaceMd),
            ],
            if (title != null)
              Text(
                title!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: dims.titleSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (description != null) ...[
              SizedBox(height: theme.spaceSm),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: dims.bodySize,
                  height: 1.4,
                ),
              ),
            ],
            if (action != null) ...[
              SizedBox(height: theme.spaceMd),
              action!,
            ],
          ],
        ),
      ),
    );
  }

  static _EmptyDims _dims(EmptySize size) => switch (size) {
        EmptySize.sm => const _EmptyDims(
            iconSize: 28,
            titleSize: 14,
            bodySize: 12,
          ),
        EmptySize.md => const _EmptyDims(
            iconSize: 40,
            titleSize: 16,
            bodySize: 13,
          ),
        EmptySize.lg => const _EmptyDims(
            iconSize: 56,
            titleSize: 20,
            bodySize: 14,
          ),
      };
}

class _EmptyDims {
  const _EmptyDims({
    required this.iconSize,
    required this.titleSize,
    required this.bodySize,
  });

  final double iconSize;
  final double titleSize;
  final double bodySize;
}
