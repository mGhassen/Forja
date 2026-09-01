import 'dart:async';

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

@immutable
class SearchResultsState {
  const SearchResultsState({
    required this.query,
    this.sections = const [],
    this.tmdbDone = false,
    this.addonsDone = false,
  });

  static const empty = SearchResultsState(query: '');

  final String query;
  final List<SearchResultSection> sections;
  final bool tmdbDone;
  final bool addonsDone;

  bool get isSearching =>
      query.isNotEmpty && (!tmdbDone || !addonsDone);

  SearchResultsState copyWith({
    String? query,
    List<SearchResultSection>? sections,
    bool? tmdbDone,
    bool? addonsDone,
  }) {
    return SearchResultsState(
      query: query ?? this.query,
      sections: sections ?? this.sections,
      tmdbDone: tmdbDone ?? this.tmdbDone,
      addonsDone: addonsDone ?? this.addonsDone,
    );
  }
}

/// Stremio addons that support search (loaded once per provider scope).
final searchAddonProvidersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final stremio = StremioService();
  final catalogs = await stremio.getAllCatalogs();
  final Map<String, Map<String, dynamic>> providers = {};
  for (final c in catalogs) {
    if (c['supportsSearch'] != true) continue;
    // Live Matches catalogs (flixnest `*-live*`, sport, …) stay out of Search.
    if (StremioAddonFeatures.catalogLooksLive({
      'type': c['catalogType'],
      'id': c['catalogId'],
      'name': c['catalogName'],
    })) {
      continue;
    }
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
/// same titles as the result cards. Waits for the TMDB slice only.
final searchHelperTitlesProvider =
    FutureProvider.autoDispose.family<List<String>, String>((ref, rawQuery) async {
  final query = rawQuery.trim();
  if (query.isEmpty) {
    return ref.watch(searchTrendingTitlesProvider.future);
  }

  final ready = Completer<SearchResultsState>();
  ref.listen<SearchResultsState>(
    searchResultsProvider(query),
    (_, next) {
      if (next.tmdbDone && !ready.isCompleted) ready.complete(next);
    },
    fireImmediately: true,
  );
  final search = await ready.future;

  Movie? seed;
  final exclude = <String>{};
  for (final section in search.sections) {
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

/// Progressive TMDB + VOD addon search for a trimmed query.
class SearchResultsNotifier
    extends AutoDisposeFamilyNotifier<SearchResultsState, String> {
  int _gen = 0;

  @override
  SearchResultsState build(String rawQuery) {
    final query = rawQuery.trim();
    if (query.isEmpty) return SearchResultsState.empty;

    final gen = ++_gen;
    var disposed = false;
    ref.onDispose(() => disposed = true);

    Future.microtask(() => _run(query, gen, () => disposed));
    return SearchResultsState(query: query);
  }

  bool _stale(int gen, bool Function() disposed) =>
      disposed() || gen != _gen;

  Future<void> _run(
    String query,
    int gen,
    bool Function() disposed,
  ) async {
    final api = TmdbApi();
    final stremio = StremioService();
    var sections = <SearchResultSection>[];

    final parsed = parseSearchQuery(query);
    // Addons get title/person text — not score/year/type tokens; genre labels OK.
    final addonQuery = () {
      final remainder = parsed.remainder.trim();
      if (remainder.isNotEmpty) return remainder;
      final genre = parsed.matchedGenreLabel?.trim();
      if (genre != null && genre.isNotEmpty) return genre;
      if (parsed.hasStructuredFilters) return '';
      return query;
    }();

    try {
      final results = await api.searchStructured(query);
      if (_stale(gen, disposed)) return;
      if (results.isNotEmpty) {
        sections = [
          SearchResultSection(
            key: 'tmdb',
            title: 'TMDB',
            isTmdb: true,
            results: results,
          ),
        ];
      }
    } catch (e) {
      debugPrint('TMDB search error: $e');
    }
    if (_stale(gen, disposed)) return;
    state = SearchResultsState(
      query: query,
      sections: sections,
      tmdbDone: true,
      addonsDone: false,
    );

    List<Map<String, dynamic>> addonProviders;
    try {
      addonProviders = await ref.read(searchAddonProvidersProvider.future);
    } catch (e) {
      debugPrint('Search addon providers error: $e');
      addonProviders = const [];
    }
    if (_stale(gen, disposed)) return;

    if (addonProviders.isEmpty || addonQuery.isEmpty) {
      state = state.copyWith(addonsDone: true);
      return;
    }

    // Per-provider type buckets accumulate as catalogs finish.
    final byProviderType =
        <String, Map<String, List<Map<String, dynamic>>>>{};
    final providerMeta = <String, ({String name, String icon})>{};

    await Future.wait(
      addonProviders.expand((provider) {
        final providerBaseUrl = provider['baseUrl'] as String;
        final providerName = provider['name'] as String;
        final providerIcon = provider['icon']?.toString() ?? '';
        providerMeta[providerBaseUrl] =
            (name: providerName, icon: providerIcon);
        byProviderType.putIfAbsent(
          providerBaseUrl,
          () => <String, List<Map<String, dynamic>>>{},
        );
        final catalogs =
            provider['catalogs'] as List<Map<String, dynamic>>;
        return catalogs.map((cat) async {
          try {
            final results = await stremio.getCatalog(
              baseUrl: cat['addonBaseUrl'],
              type: cat['catalogType'],
              id: cat['catalogId'],
              search: addonQuery,
            );
            if (_stale(gen, disposed)) return;
            for (final r in results) {
              r['_addonBaseUrl'] = providerBaseUrl;
              r['_addonName'] = providerName;
            }
            final type = cat['catalogType']?.toString() ?? 'other';
            final bucket = byProviderType[providerBaseUrl]!;
            bucket.putIfAbsent(type, () => []);
            bucket[type]!.addAll(results);
            if (_stale(gen, disposed)) return;
            state = state.copyWith(
              sections: _mergeSections(
                tmdb: sections,
                byProviderType: byProviderType,
                providerMeta: providerMeta,
              ),
            );
          } catch (_) {}
        });
      }),
    );

    if (_stale(gen, disposed)) return;
    state = state.copyWith(
      sections: _mergeSections(
        tmdb: sections,
        byProviderType: byProviderType,
        providerMeta: providerMeta,
      ),
      addonsDone: true,
    );
  }

  List<SearchResultSection> _mergeSections({
    required List<SearchResultSection> tmdb,
    required Map<String, Map<String, List<Map<String, dynamic>>>> byProviderType,
    required Map<String, ({String name, String icon})> providerMeta,
  }) {
    final out = List<SearchResultSection>.from(tmdb);
    for (final entry in byProviderType.entries) {
      final meta = providerMeta[entry.key];
      if (meta == null) continue;
      for (final typeEntry in entry.value.entries) {
        final seen = <String>{};
        final deduped = typeEntry.value.where((r) {
          final id = r['id']?.toString() ?? '';
          if (id.isEmpty || seen.contains(id)) return false;
          seen.add(id);
          return true;
        }).toList();
        if (deduped.isEmpty) continue;
        final typeLabel = typeEntry.key == 'series'
            ? 'Shows'
            : (typeEntry.key == 'movie' ? 'Movies' : typeEntry.key);
        out.add(
          SearchResultSection(
            key: '${entry.key}_${typeEntry.key}',
            title: '${meta.name} $typeLabel',
            icon: meta.icon,
            results: deduped,
          ),
        );
      }
    }
    return out;
  }
}

final searchResultsProvider = NotifierProvider.autoDispose
    .family<SearchResultsNotifier, SearchResultsState, String>(
  SearchResultsNotifier.new,
);
