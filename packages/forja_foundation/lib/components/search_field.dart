import 'package:flutter/material.dart';
import 'package:forja_foundation/components/input.dart';

/// Search-styled text field (leading search icon).
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.hintText = 'Search',
    this.enabled = true,
    this.size = InputSize.md,
    this.autofocus = false,
    this.onClear,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? hintText;
  final bool enabled;
  final InputSize size;
  final bool autofocus;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Input(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      hintText: hintText,
      enabled: enabled,
      size: size,
      autofocus: autofocus,
      variant: InputVariant.search,
      textInputAction: TextInputAction.search,
      suffixIcon: onClear == null
          ? null
          : IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close, size: 18),
            ),
    );
  }
}
