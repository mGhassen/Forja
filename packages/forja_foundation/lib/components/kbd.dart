import 'package:flutter/material.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';

/// Keyboard key glyph (shortcuts / docs UI).
class Kbd extends StatelessWidget {
  const Kbd({
    super.key,
    required this.keys,
  });

  /// Key labels, e.g. `['⌘', 'K']` or `['Ctrl', 'Enter']`.
  final List<String> keys;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0)
            Text(
              '+',
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(theme.radiusSm),
              border: Border.all(color: theme.borderSubtle),
            ),
            child: Text(
              keys[i],
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
                height: 1.2,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
