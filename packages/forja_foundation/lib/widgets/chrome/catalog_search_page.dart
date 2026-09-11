import 'package:flutter/material.dart';
import 'package:forja_foundation/blocks/search/search_block.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';

/// Hub search result row model (Zone A — no host types).
class CatalogSearchResult {
  const CatalogSearchResult({
    required this.key,
    required this.title,
    required this.posterUrl,
    this.backdropUrl,
    this.subtitle,
    this.rating,
    required this.payload,
  });

  final String key;
  final String title;
  final String posterUrl;
  final String? backdropUrl;
  final String? subtitle;
  final double? rating;
  final Object payload;
}

/// Catalog search page paint — field + results slots (Zone A).
///
/// Host wires MetaRuntime / recent queries / TV into callbacks.
class CatalogSearchPage extends StatelessWidget {
  const CatalogSearchPage({
    super.key,
    required this.results,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.hintText = 'Search',
    this.header,
    this.filters,
    this.emptyChild,
    this.backgroundColor,
  });

  final Widget results;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String hintText;
  final Widget? header;
  final Widget? filters;
  final Widget? emptyChild;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final block = SearchBlock(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      hintText: hintText,
      header: header,
      results: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (filters != null) filters!,
          Expanded(child: results),
        ],
      ),
    );

    return ColoredBox(
      color: backgroundColor ?? theme.bgDark,
      child: emptyChild == null
          ? block
          : Stack(
              fit: StackFit.expand,
              children: [
                block,
                emptyChild!,
              ],
            ),
    );
  }
}
