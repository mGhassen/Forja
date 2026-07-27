import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rust/rust.dart';

/// One provider result section (TMDB or Stremio addon).
class SearchResultSection {
  const SearchResultSection({
    required this.key,
    required this.title,
    this.icon,
    this.isTmdb = false,
    this.results = const [],
  });

  final String key;
  final String title;
  final String? icon;
  final bool isTmdb;
  final List<dynamic> results;
}

/// Stremio addons that support search (loaded once per provider scope).
final searchAddonProvidersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final stremio = StremioService();
  final catalogs = await stremio.getAllCatalogs();
  final Map<String, Map<String, dynamic>> providers = {};
  for (final c in catalogs) {
    if (c['supportsSearch'] != true) continue;
    final key = c['addonBaseUrl'] as String;
    if (!providers.containsKey(key)) {
      providers[key] = {
        'id': key,
        'name': c['addonName'],
        'icon': c['addonIcon'],
        'baseUrl': key,
        'catalogs': <Map<String, dynamic>>[],
      };
    }
    (providers[key]!['catalogs'] as List).add(c);
  }
  return providers.values.toList();
});

/// Trending titles for empty-state helper chips.
final searchTrendingTitlesProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  final api = TmdbApi();
  try {
    final movies = await api.getTrending();
    final shows = await api.getTrendingTv();
    final titles = <String>[];
    for (final item in [...movies, ...shows]) {
      if (item.title.isEmpty || titles.contains(item.title)) continue;
      titles.add(item.title);
      if (titles.length >= 12) break;
    }
    return titles;
  } catch (_) {
    return const [];
  }
});

/// Unified TMDB + addon search for a trimmed query.
final searchResultsProvider = FutureProvider.autoDispose
    .family<List<SearchResultSection>, String>((ref, rawQuery) async {
  final query = rawQuery.trim();
  if (query.isEmpty) return const [];

  final addonProviders = await ref.watch(searchAddonProvidersProvider.future);
  final api = TmdbApi();
  final stremio = StremioService();

  final sections = <SearchResultSection>[];

  try {
    final results = await api.searchMulti(query);
    final movies = results.where((m) => m.mediaType == 'movie').toList();
    final shows = results.where((m) => m.mediaType == 'tv').toList();
    if (movies.isNotEmpty) {
      sections.add(
        SearchResultSection(
          key: 'tmdb_movies',
          title: 'TMDB Movies',
          isTmdb: true,
          results: movies,
        ),
      );
    }
    if (shows.isNotEmpty) {
      sections.add(
        SearchResultSection(
          key: 'tmdb_shows',
          title: 'TMDB Shows',
          isTmdb: true,
          results: shows,
        ),
      );
    }
  } catch (e) {
    debugPrint('TMDB search error: $e');
  }

  for (final provider in addonProviders) {
    final providerBaseUrl = provider['baseUrl'] as String;
    final providerName = provider['name'] as String;
    final providerIcon = provider['icon']?.toString() ?? '';
    final catalogs = provider['catalogs'] as List<Map<String, dynamic>>;

    final Map<String, List<Map<String, dynamic>>> byType = {};

    await Future.wait(
      catalogs.map((cat) async {
        try {
          final results = await stremio.getCatalog(
            baseUrl: cat['addonBaseUrl'],
            type: cat['catalogType'],
            id: cat['catalogId'],
            search: query,
          );
          for (final r in results) {
            r['_addonBaseUrl'] = providerBaseUrl;
            r['_addonName'] = providerName;
          }
          final type = cat['catalogType']?.toString() ?? 'other';
          byType.putIfAbsent(type, () => []);
          byType[type]!.addAll(results);
        } catch (_) {}
      }),
    );

    for (final entry in byType.entries) {
      final seen = <String>{};
      final deduped = entry.value.where((r) {
        final id = r['id']?.toString() ?? '';
        if (id.isEmpty || seen.contains(id)) return false;
        seen.add(id);
        return true;
      }).toList();

      if (deduped.isEmpty) continue;

      final typeLabel = entry.key == 'series'
          ? 'Shows'
          : (entry.key == 'movie' ? 'Movies' : entry.key);
      sections.add(
        SearchResultSection(
          key: '${providerBaseUrl}_${entry.key}',
          title: '$providerName $typeLabel',
          icon: providerIcon,
          results: deduped,
        ),
      );
    }
  }

  return sections;
});
