import 'package:flutter/material.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';

/// A single breadcrumb segment.
class BreadcrumbItem {
  const BreadcrumbItem({
    required this.label,
    this.onTap,
  });

  final String label;
  final VoidCallback? onTap;
}

/// Horizontal breadcrumb trail.
class Breadcrumb extends StatelessWidget {
  const Breadcrumb({
    super.key,
    required this.items,
    this.separator,
  });

  final List<BreadcrumbItem> items;
  final Widget? separator;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final sep = separator ??
        Padding(
          padding: EdgeInsets.symmetric(horizontal: theme.spaceSm / 2),
          child: Icon(
            Icons.chevron_right,
            size: 16,
            color: theme.textSecondary,
          ),
        );

    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) children.add(sep);
      final item = items[i];
      final isLast = i == items.length - 1;
      final text = Text(
        item.label,
        style: TextStyle(
          color: isLast ? theme.textPrimary : theme.textSecondary,
          fontSize: 13,
          fontWeight: isLast ? FontWeight.w700 : FontWeight.w500,
        ),
      );
      children.add(
        item.onTap == null || isLast
            ? text
            : InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.circular(theme.radiusSm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                  child: text,
                ),
              ),
      );
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}
