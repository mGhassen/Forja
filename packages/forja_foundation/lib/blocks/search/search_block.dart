import 'package:flutter/material.dart';
import 'package:forja_foundation/blocks/props_map.dart';
import 'package:forja_foundation/components/input.dart';
import 'package:forja_foundation/tokens/forja_theme_extension.dart';

/// Prebuilt search chrome: field + optional filters + results area.
///
/// ```json
/// { "type": "search", "props": { "hintText": "Search titles" } }
/// ```
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
    this.filters,
    this.field,
  });

  factory SearchBlock.fromProps(
    Map<String, dynamic> props, {
    Widget? results,
    TextEditingController? controller,
    FocusNode? focusNode,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    Widget? header,
    Widget? filters,
    Widget? field,
  }) {
    return SearchBlock(
      results: results ?? const SizedBox.shrink(),
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      hintText: propsStringOr(props, 'hintText', 'Search'),
      header: header,
      filters: filters,
      field: field,
    );
  }

  final Widget results;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String hintText;
  final Widget? header;
  final Widget? filters;
  final Widget? field;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?header,
        field ??
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
        ?filters,
        Expanded(child: results),
      ],
    );
  }
}
