import 'package:flutter/material.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/catalog/runtime.dart';
import 'package:forja/shared/catalog/shell/catalog_open.dart';
import 'package:forja/shared/catalog/kit/chrome/hub_search_page.dart';

/// Hub search backed by a catalog plugin `search` action.
class CatalogSearchScreen extends StatelessWidget {
  const CatalogSearchScreen({
    super.key,
    required this.pluginId,
    required this.tabId,
    this.hintText = 'Search…',
  });

  final String pluginId;
  final String tabId;
  final String hintText;

  Future<List<HubSearchResult>> _search(String query) async {
    final env = await CatalogRuntime.instance.run(
      pluginId: pluginId,
      action: 'search',
      params: {'query': query, 'limit': 40},
    );
    if (!env.ok) return const [];
    return [
      for (final item in env.items)
        HubSearchResult(
          key: item.id,
          title: item.name,
          posterUrl: item.poster,
          backdropUrl: item.background.isEmpty ? null : item.background,
          subtitle: item.releaseInfo.isEmpty ? null : item.releaseInfo,
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
    return HubSearchPage(
      hintText: hintText,
      tvTabId: tabId,
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
    );
  }
}
