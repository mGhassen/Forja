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

  Future<List<String>> _idleRecommendations() async {
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
    if (seed is! AnimeCard) return _idleRecommendations();

    final exclude = {
      for (final r in results)
        if (r.title.trim().isNotEmpty) r.title.trim().toLowerCase(),
    };

    final genre = seed.genres.isNotEmpty ? seed.genres.first : null;
    final lists = await Future.wait([
      _service.getRecommendations(seed.id, perPage: 24),
      if (genre != null)
        _service.browse(genre: genre, perPage: 30)
      else
        Future.value(const <AnimeCard>[]),
      if (seed.seasonYear != null)
        _service.browse(year: seed.seasonYear, perPage: 24)
      else
        Future.value(const <AnimeCard>[]),
      if (seed.format != null && seed.format!.isNotEmpty)
        _service.browse(format: seed.format, perPage: 24)
      else
        Future.value(const <AnimeCard>[]),
    ]);

    final queues = [for (final list in lists) List<AnimeCard>.from(list)];
    final titles = <String>[];
    final seen = Set<String>.from(exclude);
    var madeProgress = true;
    while (madeProgress && titles.length < 64) {
      madeProgress = false;
      for (final queue in queues) {
        while (queue.isNotEmpty) {
          final item = queue.removeAt(0);
          final title = item.displayTitle.trim();
          if (title.isEmpty || !seen.add(title.toLowerCase())) continue;
          titles.add(title);
          madeProgress = true;
          break;
        }
        if (titles.length >= 64) break;
      }
    }
    if (titles.isNotEmpty) return titles;
    return _idleRecommendations();
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
