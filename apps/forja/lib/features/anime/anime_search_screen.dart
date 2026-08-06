import 'package:flutter/material.dart';

import 'package:forja/features/anime/catalog/anime_service.dart';
import 'package:forja/shared/widgets/hub/hub_search_page.dart';
import 'anime_details_screen.dart';

class AnimeSearchScreen extends StatelessWidget {
  const AnimeSearchScreen({super.key});

  static final AnimeService _service = AnimeService();

  HubSearchResult _mapAnime(AnimeCard anime) {
    final subtitle = [
      if (anime.seasonYear != null) '${anime.seasonYear}',
      if (anime.episodes != null) '${anime.episodes} eps',
    ].join(' · ');

    return HubSearchResult(
      key: 'anime:${anime.id}',
      title: anime.displayTitle,
      posterUrl: anime.coverUrl,
      backdropUrl: anime.bannerOrCover,
      subtitle: subtitle.isEmpty ? null : subtitle,
      rating: (anime.averageScore ?? 0) > 0 ? anime.averageScore! / 10 : null,
      payload: anime,
    );
  }

  Future<List<String>> _loadRecommendations() async {
    final batches = await Future.wait([
      _service.getTrending(perPage: 50),
      _service.browse(sort: 'POPULARITY_DESC', perPage: 50),
    ]);
    final titles = <String>[];
    final seen = <String>{};
    for (final anime in [...batches[0], ...batches[1]]) {
      final title = anime.displayTitle.trim();
      if (title.isEmpty || !seen.add(title.toLowerCase())) continue;
      titles.add(title);
      if (titles.length >= 64) break;
    }
    return titles;
  }

  Future<List<HubSearchResult>> _search(String query) async {
    final results = await _service.search(query, perPage: 30);
    return results.map(_mapAnime).toList();
  }

  @override
  Widget build(BuildContext context) {
    return HubSearchPage(
      hintText: 'Search anime…',
      tvTabId: 'anime',
      loadRecommendations: _loadRecommendations,
      onSearch: _search,
      onOpen: (result) => openAnimeDetails(context, result.payload as AnimeCard),
    );
  }
}
