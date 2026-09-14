import 'package:flutter/material.dart';
import 'package:forja_foundation/widgets/chrome/catalog_search_page.dart';

/// Catalog search screen chrome — slots only (Zone A).
///
/// Host [KitSearchScreen] wires MetaRuntime + openMetaItem into [onSearch] /
/// [onOpen].
class CatalogSearchScreen extends StatelessWidget {
  const CatalogSearchScreen({
    super.key,
    required this.onSearch,
    required this.onOpen,
    this.hintText = 'Search…',
    this.structuredSearch = false,
    this.loadRecommendations,
    this.pageBuilder,
    this.tvTabId,
  });

  final Future<List<CatalogSearchResult>> Function(String query) onSearch;
  final void Function(CatalogSearchResult result) onOpen;
  final String hintText;
  final bool structuredSearch;
  final Future<List<String>> Function({
    required String query,
    required List<CatalogSearchResult> results,
  })? loadRecommendations;
  final String? tvTabId;

  /// Host builds the full [CatalogSearchPage] / TV overlay.
  final Widget Function({
    required Future<List<CatalogSearchResult>> Function(String query) onSearch,
    required void Function(CatalogSearchResult result) onOpen,
    required String hintText,
    required bool structuredSearch,
    Future<List<String>> Function({
      required String query,
      required List<CatalogSearchResult> results,
    })? loadRecommendations,
  })? pageBuilder;

  @override
  Widget build(BuildContext context) {
    final builder = pageBuilder;
    if (builder != null) {
      return builder(
        onSearch: onSearch,
        onOpen: onOpen,
        hintText: hintText,
        structuredSearch: structuredSearch,
        loadRecommendations: loadRecommendations,
      );
    }
    return CatalogSearchPage(
      hintText: hintText,
      results: const Center(child: Text('Search')),
    );
  }
}
