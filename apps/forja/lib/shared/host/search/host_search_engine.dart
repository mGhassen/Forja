import 'package:flutter/foundation.dart';
import 'package:forja/shared/host/search/host_search_models.dart';
import 'package:rust/rust.dart';

/// Progressive TMDB + VOD Stremio addon search (host engine for hub `host_search`).
///
/// Screen chrome stays [KitSearchScreen] / pack `search`. This class owns the
/// former archive Search tab fetch path.
///
/// TMDB loads **one page** first; [loadMoreTmdb] appends pages 2…[HostSearchState.maxTmdbPages]
/// on scroll (not infinite).
class HostSearchEngine {
  HostSearchEngine({
    TmdbApi? tmdb,
    StremioService? stremio,
  })  : _tmdb = tmdb ?? TmdbApi(),
        _stremio = stremio ?? StremioService();

  final TmdbApi _tmdb;
  final StremioService _stremio;

  int _gen = 0;
  String _query = '';
  int _tmdbPage = 0;
  List<Movie> _tmdbResults = [];
  final Set<String> _tmdbSeen = {};
  List<HostSearchSection> _addonSections = [];
  bool _addonsDone = false;

  /// Cancel in-flight work (new query / dispose).
  void cancel() => _gen++;

  bool get canLoadMore =>
      _query.isNotEmpty &&
      _tmdbPage > 0 &&
      _tmdbPage < HostSearchState.maxTmdbPages;

  /// Run progressive search. [onUpdate] may fire multiple times (TMDB first).
  Future<HostSearchState> run(
    String rawQuery, {
    required void Function(HostSearchState state) onUpdate,
  }) async {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      _resetSession();
      const empty = HostSearchState.empty;
      onUpdate(empty);
      return empty;
    }

    final gen = ++_gen;
    bool stale() => gen != _gen;

    _query = query;
    _tmdbPage = 0;
    _tmdbResults = [];
    _tmdbSeen.clear();
    _addonSections = [];
    _addonsDone = false;

    final parsed = parseSearchQuery(query);
    final addonQuery = () {
      final remainder = parsed.remainder.trim();
      if (remainder.isNotEmpty) return remainder;
      final genre = parsed.matchedGenreLabel?.trim();
      if (genre != null && genre.isNotEmpty) return genre;
      if (parsed.hasStructuredFilters) return '';
      return query;
    }();

    try {
      await _appendTmdbPage(1);
    } catch (e) {
      debugPrint('HostSearch TMDB error: $e');
    }
    if (stale()) return HostSearchState(query: query);

    var state = _snapshot(
      tmdbDone: true,
      addonsDone: false,
    );
    onUpdate(state);

    List<Map<String, dynamic>> addonProviders;
    try {
      addonProviders = await listSearchableAddonProviders();
    } catch (e) {
      debugPrint('HostSearch addon providers error: $e');
      addonProviders = const [];
    }
    if (stale()) return state;

    if (addonProviders.isEmpty || addonQuery.isEmpty) {
      _addonsDone = true;
      state = _snapshot(tmdbDone: true, addonsDone: true);
      onUpdate(state);
      return state;
    }

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
            final results = await _stremio.getCatalog(
              baseUrl: cat['addonBaseUrl'],
              type: cat['catalogType'],
              id: cat['catalogId'],
              search: addonQuery,
            );
            if (stale()) return;
            for (final r in results) {
              r['_addonBaseUrl'] = providerBaseUrl;
              r['_addonName'] = providerName;
            }
            final type = cat['catalogType']?.toString() ?? 'other';
            final bucket = byProviderType[providerBaseUrl]!;
            bucket.putIfAbsent(type, () => []);
            bucket[type]!.addAll(results);
            if (stale()) return;
            _addonSections = _addonOnlySections(
              byProviderType: byProviderType,
              providerMeta: providerMeta,
            );
            state = _snapshot(tmdbDone: true, addonsDone: false);
            onUpdate(state);
          } catch (_) {}
        });
      }),
    );

    if (stale()) return state;
    _addonsDone = true;
    _addonSections = _addonOnlySections(
      byProviderType: byProviderType,
      providerMeta: providerMeta,
    );
    state = _snapshot(tmdbDone: true, addonsDone: true);
    onUpdate(state);
    return state;
  }

  /// Append the next TMDB page for the active query (max [HostSearchState.maxTmdbPages]).
  Future<HostSearchState?> loadMoreTmdb({
    required void Function(HostSearchState state) onUpdate,
  }) async {
    if (!canLoadMore) return null;
    final gen = _gen;
    final nextPage = _tmdbPage + 1;
    try {
      final before = _tmdbResults.length;
      await _appendTmdbPage(nextPage);
      if (gen != _gen) return null;
      // Empty page → stop offering more.
      if (_tmdbResults.length == before) {
        _tmdbPage = HostSearchState.maxTmdbPages;
      }
    } catch (e) {
      debugPrint('HostSearch TMDB loadMore error: $e');
      if (gen != _gen) return null;
    }
    final state = _snapshot(tmdbDone: true, addonsDone: _addonsDone);
    onUpdate(state);
    return state;
  }

  Future<void> _appendTmdbPage(int page) async {
    final chunk = await _tmdb.searchStructured(_query, page: page);
    for (final m in chunk) {
      final key = '${m.mediaType}:${m.id}';
      if (!_tmdbSeen.add(key)) continue;
      _tmdbResults.add(m);
    }
    _tmdbPage = page;
  }

  void _resetSession() {
    _query = '';
    _tmdbPage = 0;
    _tmdbResults = [];
    _tmdbSeen.clear();
    _addonSections = [];
    _addonsDone = false;
  }

  HostSearchState _snapshot({
    required bool tmdbDone,
    required bool addonsDone,
  }) {
    final tmdbSection = _tmdbResults.isEmpty
        ? const <HostSearchSection>[]
        : [
            HostSearchSection(
              key: 'tmdb',
              title: 'TMDB',
              isTmdb: true,
              results: List<Movie>.from(_tmdbResults),
            ),
          ];
    return HostSearchState(
      query: _query,
      sections: [...tmdbSection, ..._addonSections],
      tmdbDone: tmdbDone,
      addonsDone: addonsDone,
      tmdbPage: _tmdbPage,
      canLoadMore: canLoadMore,
    );
  }

  /// Stremio addons with search catalogs (excludes Live Sports).
  Future<List<Map<String, dynamic>>> listSearchableAddonProviders() async {
    final catalogs = await _stremio.getAllCatalogs();
    final Map<String, Map<String, dynamic>> providers = {};
    for (final c in catalogs) {
      if (c['supportsSearch'] != true) continue;
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
  }

  List<HostSearchSection> _addonOnlySections({
    required Map<String, Map<String, List<Map<String, dynamic>>>> byProviderType,
    required Map<String, ({String name, String icon})> providerMeta,
  }) {
    final out = <HostSearchSection>[];
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
          HostSearchSection(
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
