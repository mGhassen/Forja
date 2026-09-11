import 'package:flutter/material.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';

/// Page indicator dots.
class PageDots extends StatelessWidget {
  const PageDots({
    super.key,
    required this.count,
    required this.index,
    this.onChanged,
    this.size = 8,
    this.spacing,
  });

  final int count;
  final int index;
  final ValueChanged<int>? onChanged;
  final double size;
  final double? spacing;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final gap = spacing ?? theme.spaceSm;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) SizedBox(width: gap),
          GestureDetector(
            onTap: onChanged == null ? null : () => onChanged!(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: i == index ? size * 2.2 : size,
              height: size,
              decoration: BoxDecoration(
                color: i == index
                    ? theme.brandGreen
                    : theme.textSecondary.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Alias matching pagination family naming.
typedef Pagination = PageDots;
