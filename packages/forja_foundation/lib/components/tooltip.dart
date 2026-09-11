import 'package:flutter/material.dart' hide Tooltip;
import 'package:flutter/material.dart' as material show Tooltip;
import 'package:forja_foundation/theme/forja_theme_extension.dart';

/// Forja-styled tooltip wrapper around Material [Tooltip].
class Tooltip extends StatelessWidget {
  const Tooltip({
    super.key,
    required this.message,
    required this.child,
    this.waitDuration = const Duration(milliseconds: 400),
    this.showDuration = const Duration(seconds: 2),
  });

  final String message;
  final Widget child;
  final Duration waitDuration;
  final Duration showDuration;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    if (message.trim().isEmpty) return child;
    return material.Tooltip(
      message: message,
      waitDuration: waitDuration,
      showDuration: showDuration,
      decoration: BoxDecoration(
        color: theme.surfaceElevated,
        borderRadius: BorderRadius.circular(theme.radiusSm),
        border: Border.all(color: theme.borderSubtle),
      ),
      textStyle: TextStyle(
        color: theme.textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: theme.spaceSm + 2,
        vertical: theme.spaceSm / 2 + 2,
      ),
      child: child,
    );
  }
}

/// Alias when callers prefer an explicit Forja name.
typedef ForjaTooltip = Tooltip;
