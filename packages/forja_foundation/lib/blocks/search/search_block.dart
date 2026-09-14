import 'package:flutter/material.dart';
import 'package:forja_foundation/blocks/props_map.dart';
import 'package:forja_foundation/components/input.dart';
import 'package:forja_foundation/tokens/forja_theme_extension.dart';

/// Search page template — field + optional filters + results (RFC-106 G6 · RFC-112).
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
    required Widget results,
    TextEditingController? controller,
    FocusNode? focusNode,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    Widget? header,
    Widget? filters,
    Widget? field,
  }) {
    return SearchBlock(
      results: results,
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

  /// Host-owned search field (TV browse/edit, tune button). Replaces default [Input].
  final Widget? field;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null) header!,
        if (field != null)
          field!
        else
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
        if (filters != null) filters!,
        Expanded(child: results),
      ],
    );
  }
}
