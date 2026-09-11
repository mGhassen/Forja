import 'package:flutter/material.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';

/// Visual tone for [Input].
enum InputVariant {
  outline,
  ghost,
  search,
}

/// Size scale for [Input].
enum InputSize {
  sm,
  md,
  lg,
}

/// Text field — outline / ghost / search variants.
class Input extends StatelessWidget {
  const Input({
    super.key,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.hintText,
    this.variant = InputVariant.outline,
    this.size = InputSize.md,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? hintText;
  final InputVariant variant;
  final InputSize size;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int? maxLines;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final dims = _dims(size);
    final borderColor = theme.borderSubtle;
    final radius = BorderRadius.circular(theme.radiusMd);

    final OutlineInputBorder outline = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(
        color: variant == InputVariant.ghost
            ? Colors.transparent
            : borderColor,
      ),
    );

    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: maxLines,
      autofocus: autofocus,
      style: TextStyle(
        color: theme.textPrimary,
        fontSize: dims.fontSize,
      ),
      cursorColor: theme.brandGreen,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: theme.textSecondary,
          fontSize: dims.fontSize,
        ),
        filled: variant != InputVariant.ghost,
        fillColor: variant == InputVariant.ghost
            ? null
            : Colors.white.withValues(alpha: 0.03),
        contentPadding: dims.padding,
        prefixIcon: prefixIcon ??
            (variant == InputVariant.search
                ? Icon(Icons.search, size: dims.iconSize, color: theme.textSecondary)
                : null),
        suffixIcon: suffixIcon,
        border: outline,
        enabledBorder: outline,
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(
            color: variant == InputVariant.ghost
                ? theme.brandGreen.withValues(alpha: 0.4)
                : theme.brandGreen,
          ),
        ),
        disabledBorder: outline,
      ),
    );
  }

  static _InputDims _dims(InputSize size) => switch (size) {
        InputSize.sm => const _InputDims(
            fontSize: 13,
            iconSize: 18,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        InputSize.md => const _InputDims(
            fontSize: 14,
            iconSize: 20,
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        InputSize.lg => const _InputDims(
            fontSize: 16,
            iconSize: 22,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
      };
}

class _InputDims {
  const _InputDims({
    required this.fontSize,
    required this.iconSize,
    required this.padding,
  });

  final double fontSize;
  final double iconSize;
  final EdgeInsetsGeometry padding;
}
