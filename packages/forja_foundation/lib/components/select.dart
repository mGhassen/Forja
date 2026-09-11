import 'package:flutter/material.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';

/// A select option.
class SelectOption<T> {
  const SelectOption({
    required this.value,
    required this.label,
  });

  final T value;
  final String label;
}

/// Simple dropdown select.
class Select<T> extends StatelessWidget {
  const Select({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hintText,
    this.enabled = true,
  });

  final T? value;
  final List<SelectOption<T>> options;
  final ValueChanged<T?>? onChanged;
  final String? hintText;
  final bool enabled;

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
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: theme.spaceMd),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            hint: hintText == null
                ? null
                : Text(
                    hintText!,
                    style: TextStyle(color: theme.textSecondary, fontSize: 14),
                  ),
            icon: Icon(Icons.expand_more, color: theme.textSecondary),
            dropdownColor: theme.surfaceElevated,
            style: TextStyle(color: theme.textPrimary, fontSize: 14),
            onChanged: enabled ? onChanged : null,
            items: [
              for (final opt in options)
                DropdownMenuItem<T>(
                  value: opt.value,
                  child: Text(opt.label),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
