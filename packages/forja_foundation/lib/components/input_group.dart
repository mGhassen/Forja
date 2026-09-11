import 'package:flutter/material.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';

/// Input with optional prefix / suffix slots flanking the field.
class InputGroup extends StatelessWidget {
  const InputGroup({
    super.key,
    required this.child,
    this.prefix,
    this.suffix,
  });

  final Widget child;
  final Widget? prefix;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final radius = BorderRadius.circular(theme.radiusMd);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: radius,
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Row(
        children: [
          if (prefix != null)
            Padding(
              padding: EdgeInsets.only(left: theme.spaceMd),
              child: IconTheme(
                data: IconThemeData(color: theme.textSecondary, size: 18),
                child: DefaultTextStyle(
                  style: TextStyle(color: theme.textSecondary, fontSize: 13),
                  child: prefix!,
                ),
              ),
            ),
          Expanded(
            child: Theme(
              data: Theme.of(context).copyWith(
                inputDecorationTheme: const InputDecorationTheme(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  filled: false,
                ),
              ),
              child: child,
            ),
          ),
          if (suffix != null)
            Padding(
              padding: EdgeInsets.only(right: theme.spaceMd),
              child: IconTheme(
                data: IconThemeData(color: theme.textSecondary, size: 18),
                child: DefaultTextStyle(
                  style: TextStyle(color: theme.textSecondary, fontSize: 13),
                  child: suffix!,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
