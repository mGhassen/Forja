import 'package:flutter/material.dart';
import 'package:forja_foundation/protocol/filter.dart';
import 'package:forja/shared/engine/hub/chrome_filters.dart';
import 'package:forja/shared/engine/hub/meta_movie.dart';
import 'package:forja/shared/shell/kit_search_page.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja/shared/engine/hub/meta_runtime.dart';
import 'package:forja/shared/engine/hub/catalog_open.dart';
import 'package:forja/shell/chrome/player_surface_chrome_stub.dart';
import 'package:forja_foundation/widgets/chrome/catalog_search_screen.dart';

export 'package:forja_foundation/widgets/chrome/catalog_search_screen.dart'
    show CatalogSearchScreen;

/// Hub search backed by a catalog plugin `search` action.
///
/// Host mapper — MetaRuntime + [openMetaItem] into [KitSearchPage].
class KitSearchScreen extends StatelessWidget {
  const KitSearchScreen({
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

  Future<List<KitSearchResult>> _search(String query) async {
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
    final env = await MetaRuntime.instance.run(
      pluginId: pluginId,
      action: 'search',
      params: params,
    );
    if (!env.ok) return const [];
    return [
      for (final item in env.items)
        KitSearchResult(
          key: item.id,
          title: item.name,
          posterUrl: item.poster,
          backdropUrl: item.background.isEmpty ? null : item.background,
          subtitle: kitPosterSubtitle(item),
          rating: item.rating,
          payload: item,
        ),
    ];
  }

  Future<List<String>> _recommendations({
    required String query,
    required List<KitSearchResult> results,
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
      builder: (context) => CatalogSearchScreen(
        hintText: hintText,
        tvTabId: tabId,
        structuredSearch: structuredSearch,
        onSearch: _search,
        loadRecommendations: _recommendations,
        onOpen: (result) {
          final payload = result.payload;
          if (payload is! MetaItem) return;
          openMetaItem(
            context,
            pluginId: pluginId,
            item: payload,
          );
        },
        pageBuilder: ({
          required onSearch,
          required onOpen,
          required hintText,
          required structuredSearch,
          loadRecommendations,
        }) {
          return KitSearchPage(
            hintText: hintText,
            tvTabId: tabId,
            structuredSearch: structuredSearch,
            onSearch: onSearch,
            loadRecommendations: loadRecommendations ?? _recommendations,
            onOpen: onOpen,
          );
        },
      ),
    );
  }
}
