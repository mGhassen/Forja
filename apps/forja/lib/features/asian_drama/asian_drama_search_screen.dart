import 'package:flutter/material.dart';

import 'package:forja/features/asian_drama/catalog/kisskh_service.dart';
import 'package:forja/features/asian_drama/catalog/kisskh_tmdb_match.dart';
import 'package:forja/shared/widgets/hub/hub_search_page.dart';
import 'package:rust/rust.dart';
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

  Future<List<String>> _idleRecommendations() async {
    final feed = await _service.getHome();
    final titles = <String>[];
    final seen = <String>{};
    for (final drama in [
      ...feed.trending,
      ...feed.mostViewed,
      ...feed.latest,
    ]) {
      final title = drama.title.trim();
      if (title.isEmpty || !seen.add(title.toLowerCase())) continue;
      titles.add(title);
    }
    return titles;
  }

  Future<List<String>> _loadRecommendations({
    required String query,
    required List<HubSearchResult> results,
  }) async {
    if (query.trim().isEmpty || results.isEmpty) {
      return _idleRecommendations();
    }

    final seed = results.first.payload;
    if (seed is! KdramaCard) return _idleRecommendations();

    final exclude = {
      for (final r in results)
        if (r.title.trim().isNotEmpty) r.title.trim().toLowerCase(),
    };

    try {
      final match = await KissKhTmdbMatch.resolve(
        title: seed.title,
        year: seed.year,
      );
      if (match != null) {
        final contextual = await TmdbApi().contextualSearchTitles(
          match,
          exclude: exclude,
        );
        if (contextual.isNotEmpty) return contextual;
      }
    } catch (_) {}

    // Fallback: same-year titles from home feed, then fill with idle pool.
    final year = (seed.year ?? '').trim();
    final idle = await _idleRecommendations();
    if (year.isEmpty) {
      return [
        for (final t in idle)
          if (!exclude.contains(t.toLowerCase())) t,
      ];
    }
    final sameYear = <String>[];
    final rest = <String>[];
    for (final t in idle) {
      final lower = t.toLowerCase();
      if (exclude.contains(lower)) continue;
      // Home titles don't always carry year in the string — keep year-tagged
      // subtitle matches via seed year only when title list is thin.
      if (t.contains(year)) {
        sameYear.add(t);
      } else {
        rest.add(t);
      }
    }
    return [...sameYear, ...rest];
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
