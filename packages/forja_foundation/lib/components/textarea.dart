import 'package:flutter/material.dart';
import 'package:forja_foundation/components/input.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';

/// Multi-line text field — Input-style outline defaults.
class Textarea extends StatelessWidget {
  const Textarea({
    super.key,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.hintText,
    this.minLines = 3,
    this.maxLines = 6,
    this.enabled = true,
    this.size = InputSize.md,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final String? hintText;
  final int minLines;
  final int? maxLines;
  final bool enabled;
  final InputSize size;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final fontSize = switch (size) {
      InputSize.sm => 13.0,
      InputSize.md => 14.0,
      InputSize.lg => 16.0,
    };
    final padding = switch (size) {
      InputSize.sm =>
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      InputSize.md =>
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      InputSize.lg =>
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    };
    final radius = BorderRadius.circular(theme.radiusMd);
    final outline = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: theme.borderSubtle),
    );

    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      enabled: enabled,
      minLines: minLines,
      maxLines: maxLines,
      autofocus: autofocus,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      style: TextStyle(color: theme.textPrimary, fontSize: fontSize),
      cursorColor: theme.brandGreen,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: theme.textSecondary, fontSize: fontSize),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.03),
        contentPadding: padding,
        border: outline,
        enabledBorder: outline,
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: theme.brandGreen),
        ),
        disabledBorder: outline,
      ),
    );
  }
}
