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

/// Large title pool for empty-state helpers (UI takes ≤16 after recent exclude).
final searchTrendingTitlesProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  final api = TmdbApi();
  try {
    final lists = await Future.wait([
      api.getTrending(),
      api.getTrendingTv(),
      api.getPopular(),
      api.getPopularTv(),
      api.getNowPlaying(),
      api.getOnTheAir(),
      api.getTopRated(),
    ]);

    // Round-robin across feeds so later picks stay varied (not one list's tail).
    final queues = [
      for (final list in lists) List<Movie>.from(list),
    ];
    final titles = <String>[];
    final seen = <String>{};
    const poolCap = 64;
    var madeProgress = true;
    while (madeProgress && titles.length < poolCap) {
      madeProgress = false;
      for (final queue in queues) {
        while (queue.isNotEmpty) {
          final item = queue.removeAt(0);
          final title = item.title.trim();
          if (title.isEmpty) continue;
          if (!seen.add(title.toLowerCase())) continue;
          titles.add(title);
          madeProgress = true;
          break;
        }
        if (titles.length >= poolCap) break;
      }
    }
    return titles;
  } catch (_) {
    return const [];
  }
});

/// Idle → trending pool. With a query → titles related to the top TMDB hit
/// (recs / similar / genre / year / language / director / studio) — never the
/// same titles as the result cards.
final searchHelperTitlesProvider =
    FutureProvider.autoDispose.family<List<String>, String>((ref, rawQuery) async {
  final query = rawQuery.trim();
  if (query.isEmpty) {
    return ref.watch(searchTrendingTitlesProvider.future);
  }

  final sections = await ref.watch(searchResultsProvider(query).future);
  Movie? seed;
  final exclude = <String>{};
  for (final section in sections) {
    if (!section.isTmdb) continue;
    for (final raw in section.results) {
      if (raw is! Movie) continue;
      final title = raw.title.trim();
      if (title.isNotEmpty) exclude.add(title.toLowerCase());
      seed ??= raw;
    }
  }
  if (seed == null) {
    return ref.watch(searchTrendingTitlesProvider.future);
  }

  final api = TmdbApi();
  try {
    final contextual = await api.contextualSearchTitles(
      seed,
      exclude: exclude,
    );
    if (contextual.isNotEmpty) return contextual;
  } catch (_) {}
  return ref.watch(searchTrendingTitlesProvider.future);
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
    final results = await api.searchStructured(query);
    if (results.isNotEmpty) {
      sections.add(
        SearchResultSection(
          key: 'tmdb',
          title: 'TMDB',
          isTmdb: true,
          results: results,
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
