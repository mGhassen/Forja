import 'package:flutter/material.dart';
import 'package:forja_foundation/components/input.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/tokens/forja_theme_extension.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

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
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final fontSize = switch (size) {
      InputSize.sm => tv
          ? ShellTokens.formInputFontSizeSmTv
          : ShellTokens.formInputFontSizeSm,
      InputSize.md =>
        tv ? ShellTokens.formInputFontSizeTv : ShellTokens.formInputFontSize,
      InputSize.lg => tv
          ? ShellTokens.formInputFontSizeLgTv
          : ShellTokens.formInputFontSizeLg,
    };
    final hintSize =
        tv ? ShellTokens.formInputHintFontSizeTv : fontSize;
    final padding = switch (size) {
      InputSize.sm => EdgeInsets.symmetric(
          horizontal: tv
              ? ShellTokens.formInputPadHSmTv
              : ShellTokens.formInputPadHSm,
          vertical: tv
              ? ShellTokens.formInputPadVSmTv
              : ShellTokens.formInputPadVSm,
        ),
      InputSize.md => EdgeInsets.symmetric(
          horizontal:
              tv ? ShellTokens.formInputPadHTv : ShellTokens.formInputPadH,
          vertical:
              tv ? ShellTokens.formInputPadVTv : ShellTokens.formInputPadV,
        ),
      InputSize.lg => EdgeInsets.symmetric(
          horizontal: tv
              ? ShellTokens.formInputPadHLgTv
              : ShellTokens.formInputPadHLg,
          vertical: tv
              ? ShellTokens.formInputPadVLgTv
              : ShellTokens.formInputPadVLg,
        ),
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
        hintStyle: TextStyle(color: theme.textSecondary, fontSize: hintSize),
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
