import 'package:flutter/material.dart';

import 'package:forja/features/asian_drama/catalog/kisskh_service.dart';
import 'package:forja/shared/widgets/hub/hub_search_page.dart';
import 'asian_drama_details_screen.dart';

class AsianDramaSearchScreen extends StatelessWidget {
  const AsianDramaSearchScreen({super.key});

  static final KissKhService _service = KissKhService();

  HubSearchResult _mapDrama(KdramaCard drama) {
    return HubSearchResult(
      key: 'drama:${drama.id}',
      title: drama.title,
      posterUrl: drama.cover,
      backdropUrl: drama.cover,
      subtitle: drama.year,
      payload: drama,
    );
  }

  Future<List<String>> _loadRecommendations() async {
    final feed = await _service.getHome();
    final titles = <String>[];
    for (final drama in feed.trending) {
      if (drama.title.isEmpty || titles.contains(drama.title)) continue;
      titles.add(drama.title);
      if (titles.length >= 12) break;
    }
    if (titles.length < 12) {
      for (final drama in feed.mostViewed) {
        if (drama.title.isEmpty || titles.contains(drama.title)) continue;
        titles.add(drama.title);
        if (titles.length >= 12) break;
      }
    }
    return titles;
  }

  Future<List<HubSearchResult>> _search(String query) async {
    final results = await _service.search(query);
    return results.map(_mapDrama).toList();
  }

  @override
  Widget build(BuildContext context) {
    return HubSearchPage(
      hintText: 'Search dramas, movies…',
      tvTabId: 'asian_drama',
      loadRecommendations: _loadRecommendations,
      onSearch: _search,
      onOpen: (result) =>
          openAsianDramaDetails(context, result.payload as KdramaCard),
    );
  }
}
