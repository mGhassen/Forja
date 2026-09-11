import 'package:flutter/material.dart';
import 'package:forja_foundation/components/input.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';

/// Search page template — field + results child (RFC-106 G6).
class SearchBlock extends StatelessWidget {
  const SearchBlock({
    super.key,
    required this.results,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.hintText = 'Search',
    this.header,
  });

  final Widget results;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String hintText;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null) header!,
        Padding(
          padding: EdgeInsets.fromLTRB(
            theme.spaceLg,
            theme.spaceMd,
            theme.spaceLg,
            theme.spaceSm,
          ),
          child: Input(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            hintText: hintText,
            variant: InputVariant.search,
            prefixIcon: const Icon(Icons.search),
          ),
        ),
        Expanded(child: results),
      ],
    );
  }
}
