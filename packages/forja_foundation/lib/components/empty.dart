import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/tokens/forja_theme_extension.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

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
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final dims = _dims(size, tv: tv);

    return Center(
      child: Padding(
        padding: EdgeInsets.all(
          ShellTokens.chromeScale(theme.spaceLg, tv: tv),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: dims.iconSize, color: theme.textSecondary),
              SizedBox(height: ShellTokens.chromeScale(theme.spaceMd, tv: tv)),
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
              SizedBox(height: ShellTokens.chromeScale(theme.spaceSm, tv: tv)),
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
              SizedBox(height: ShellTokens.chromeScale(theme.spaceMd, tv: tv)),
              action!,
            ],
          ],
        ),
      ),
    );
  }

  static _EmptyDims _dims(EmptySize size, {required bool tv}) {
    final base = switch (size) {
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
    if (!tv) return base;
    return _EmptyDims(
      iconSize: ShellTokens.chromeScale(base.iconSize, tv: true),
      titleSize: ShellTokens.tvTypeSize(base.titleSize),
      bodySize: ShellTokens.tvTypeSize(base.bodySize),
    );
  }
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
