import 'package:flutter/material.dart';
import 'package:forja_foundation/blocks/search/search_block.dart';
import 'package:forja_foundation/components/settled_network_image.dart';
import 'package:forja_foundation/tokens/forja_theme_extension.dart';

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
/// Optional [backdropUrl] paints a wide-layout atmosphere stack behind slots.
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
    this.field,
    this.emptyChild,
    this.backgroundColor,
    this.backdropUrl,
  });

  final Widget results;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String hintText;
  final Widget? header;
  final Widget? filters;

  /// Host-owned search field chrome; when set, default [Input] is skipped.
  final Widget? field;
  final Widget? emptyChild;
  final Color? backgroundColor;

  /// Wide layout atmosphere — poster/backdrop behind a left→right gradient.
  final String? backdropUrl;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final bg = backgroundColor ?? theme.bgDark;
    final block = SearchBlock(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      hintText: hintText,
      header: header,
      field: field,
      filters: filters,
      results: results,
    );

    final content = emptyChild == null
        ? block
        : Stack(
            fit: StackFit.expand,
            children: [
              block,
              emptyChild!,
            ],
          );

    final url = backdropUrl;
    if (url == null || url.isEmpty) {
      return ColoredBox(color: bg, child: content);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: SettledNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
            errorWidget: const SizedBox.shrink(),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  theme.bgDark,
                  theme.bgDark.withValues(alpha: 0.92),
                  theme.bgDark.withValues(alpha: 0.55),
                ],
                stops: const [0.0, 0.42, 1.0],
              ),
            ),
          ),
        ),
        ColoredBox(color: Colors.transparent, child: content),
      ],
    );
  }
}
