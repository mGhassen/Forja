import 'package:flutter/material.dart';
import 'package:forja/shared/catalog/filter.dart';
import 'package:forja/shared/catalog/kit/chrome/catalog_chrome_filters.dart';
import 'package:forja/shared/catalog/kit/meta/catalog_meta_movie.dart';
import 'package:forja/shared/catalog/kit/chrome/hub_search_page.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/catalog/runtime.dart';
import 'package:forja/shared/catalog/shell/catalog_open.dart';
import 'package:forja/shell/player_surface_chrome_stub.dart';

/// Hub search backed by a catalog plugin `search` action.
///
/// Feature chrome is capability-gated by the caller ([structuredSearch],
/// [applyChromeFilters]) — never by pluginId / tabId.
class CatalogSearchScreen extends StatelessWidget {
  const CatalogSearchScreen({
    super.key,
    required this.pluginId,
    required this.tabId,
    this.hintText = 'Search…',
    this.structuredSearch = false,
    this.applyChromeFilters = false,
  });

  final String pluginId;
  final String tabId;
  final String hintText;
  final bool structuredSearch;
  final bool applyChromeFilters;

  Future<List<HubSearchResult>> _search(String query) async {
    final base = <String, dynamic>{'query': query, 'limit': 40};
    final params = applyChromeFilters
        ? catalogParamsWithFilters(
            base,
            filters: catalogChromeFilters(
              tabId: tabId,
              pluginId: pluginId,
            ),
          )
        : base;
    final env = await CatalogRuntime.instance.run(
      pluginId: pluginId,
      action: 'search',
      params: params,
    );
    if (!env.ok) return const [];
    return [
      for (final item in env.items)
        HubSearchResult(
          key: item.id,
          title: item.name,
          posterUrl: item.poster,
          backdropUrl: item.background.isEmpty ? null : item.background,
          subtitle: hubPosterCardSubtitle(item),
          rating: item.rating,
          payload: item,
        ),
    ];
  }

  Future<List<String>> _recommendations({
    required String query,
    required List<HubSearchResult> results,
  }) async {
    if (results.isEmpty) return const [];
    final titles = <String>[];
    for (final r in results) {
      final t = r.title.trim();
      if (t.isEmpty || titles.contains(t)) continue;
      titles.add(t);
      if (titles.length >= 12) break;
    }
    return titles;
  }

  @override
  Widget build(BuildContext context) {
    return PlayerSurfaceChromeStub(
      builder: (context) => HubSearchPage(
        hintText: hintText,
        tvTabId: tabId,
        structuredSearch: structuredSearch,
        onSearch: _search,
        loadRecommendations: _recommendations,
        onOpen: (result) {
          final payload = result.payload;
          if (payload is! CatalogMetaItem) return;
          openCatalogMetaItem(
            context,
            pluginId: pluginId,
            item: payload,
          );
        },
      ),
    );
  }
}
