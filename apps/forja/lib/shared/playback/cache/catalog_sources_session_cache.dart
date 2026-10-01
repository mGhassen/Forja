import 'package:flutter/foundation.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja/shared/engine/runtime/meta/catalog_extract_context.dart';
import 'package:rust/rust.dart';

/// Tab, chip, and toolbar state for catalog Sources (player overlay).
///
/// Details keeps this on [DetailsPlaySession] while the route is mounted;
/// the player writes it here on dismiss so reopening Sources within [CatalogSourcesSessionCache.streamTtl]
/// restores the last tab/chips/filters for the same title/episode.
@immutable
class CatalogSourcesPanelUiState {
  const CatalogSourcesPanelUiState({
    required this.kindFilter,
    required this.selectedSourceId,
    required this.nuvioSelectedScraperIds,
    required this.engineSelectedPluginIds,
    this.nuvioAllMode,
    this.engineAllMode,
    this.nuvioViewFilterScraperIds = const {},
    this.engineViewFilterPluginIds = const {},
    this.torrentViewFilterProviderIds = const {},
    this.userPickedKind = false,
    this.userPickedStremioProvider = false,
    this.searchQuery = '',
    this.qualityFilters = const {},
    this.languageFilters = const {},
    this.techFilters = const {},
    this.audioFilters = const {},
    this.sizeFilters = const {},
    this.panelSourceIdByKind = const {},
  });

  final String kindFilter;
  final String selectedSourceId;
  final Set<String> nuvioSelectedScraperIds;
  final Set<String> engineSelectedPluginIds;
  /// When null, readers infer All from a full chip selection (legacy caches).
  final bool? nuvioAllMode;
  final bool? engineAllMode;
  final Set<String> nuvioViewFilterScraperIds;
  final Set<String> engineViewFilterPluginIds;
  final Set<String> torrentViewFilterProviderIds;
  final bool userPickedKind;
  final bool userPickedStremioProvider;
  final String searchQuery;
  final Set<String> qualityFilters;
  final Set<String> languageFilters;
  final Set<String> techFilters;
  final Set<String> audioFilters;
  final Set<String> sizeFilters;
  final Map<String, String> panelSourceIdByKind;
}

/// Restores tab/chip/filter fields from a session UI snapshot.
///
/// Callers pass [kindAllowed] when play-source flags are known; when omitted,
/// the cached kind is applied as-is (details cold start).
void applyCatalogSourcesPanelUiState({
  required CatalogSourcesPanelUiState state,
  required void Function(String kindFilter) setKindFilter,
  required void Function(Set<String> ids) setNuvioSelectedScraperIds,
  required void Function(Set<String> ids) setEngineSelectedPluginIds,
  required void Function(bool? mode) setNuvioAllMode,
  required void Function(bool? mode) setEngineAllMode,
  required void Function(Set<String> ids) setNuvioViewFilterScraperIds,
  required void Function(Set<String> ids) setEngineViewFilterPluginIds,
  required void Function(Set<String> ids) setTorrentViewFilterProviderIds,
  required void Function(bool picked) setUserPickedStremioProvider,
  required void Function(String query) setSearchQuery,
  required void Function(Set<String> filters) setQualityFilters,
  required void Function(Set<String> filters) setLanguageFilters,
  required void Function(Set<String> filters) setTechFilters,
  required void Function(Set<String> filters) setAudioFilters,
  required void Function(Set<String> filters) setSizeFilters,
  required void Function(Map<String, String> byKind) setPanelSourceIdByKind,
  bool Function(String kind)? kindAllowed,
}) {
  final kindOk =
      kindAllowed == null || kindAllowed(state.kindFilter);
  if (kindOk) setKindFilter(state.kindFilter);
  setNuvioSelectedScraperIds(Set<String>.from(state.nuvioSelectedScraperIds));
  setEngineSelectedPluginIds(Set<String>.from(state.engineSelectedPluginIds));
  setNuvioAllMode(state.nuvioAllMode);
  setEngineAllMode(state.engineAllMode);
  setNuvioViewFilterScraperIds(
    Set<String>.from(state.nuvioViewFilterScraperIds),
  );
  setEngineViewFilterPluginIds(
    Set<String>.from(state.engineViewFilterPluginIds),
  );
  setTorrentViewFilterProviderIds(
    Set<String>.from(state.torrentViewFilterProviderIds),
  );
  setUserPickedStremioProvider(state.userPickedStremioProvider);
  setSearchQuery(state.searchQuery);
  setQualityFilters(Set<String>.from(state.qualityFilters));
  setLanguageFilters(Set<String>.from(state.languageFilters));
  setTechFilters(Set<String>.from(state.techFilters));
  setAudioFilters(Set<String>.from(state.audioFilters));
  setSizeFilters(Set<String>.from(state.sizeFilters));
  setPanelSourceIdByKind(Map<String, String>.from(state.panelSourceIdByKind));
}

/// In-memory TTL cache for catalog Sources (Torrents / Stremio / Nuvio / Engine).
///
/// Shared by media-details and the in-player Sources panel so reopening the
/// panel within [streamTtl] reuses the last fetch. Torrents / Stremio still drop
/// empty lists (flaky search). Forja / Nuvio keep fetched markers even when a
/// scraper returned nothing so hub overlay reopen matches movie details RAM
/// (explicit kind/chip reload still force-refetches).
///
/// Hover-probe green/red uses a shorter [probeHealthTtl] so status can go
/// stale while stream rows stay warm.
class CatalogSourcesSessionCache {
  CatalogSourcesSessionCache._();

  /// Stream lists + panel UI (tabs / chips / filters).
  static const streamTtl = Duration(hours: 1);

  /// Hover-probe left-bar green/red.
  static const probeHealthTtl = Duration(minutes: 15);

  /// Alias for [streamTtl] (call sites / docs that say "session TTL").
  static const ttl = streamTtl;

  static const _maxEntriesPerKind = 48;

  static final _torrents =
      <
        String,
        ({
          DateTime at,
          List<TorrentResult> results,
          Set<String> fetchedProviderIds,
        })
      >{};
  static final _stremio =
      <String, ({DateTime at, List<Map<String, dynamic>> streams})>{};
  static final _nuvio =
      <
        String,
        ({
          DateTime at,
          List<Map<String, dynamic>> streams,
          Set<String> fetchedScraperIds,
        })
      >{};
  static final _engine =
      <
        String,
        ({
          DateTime at,
          List<Map<String, dynamic>> streams,
          Set<String> fetchedPluginIds,
        })
      >{};
  static final _ui =
      <String, ({DateTime at, CatalogSourcesPanelUiState state})>{};

  /// Hover-probe green/red for stream rows — survives panel dispose/reopen.
  /// Keyed by stream URL (same identity as the Sources tile).
  static final _probeHealth = <String, ({DateTime at, bool ok})>{};

  /// Stable key for a title/episode Sources session.
  ///
  /// Prefer [metaOpen] so hub tabs stay on one key when TMDB enrichment
  /// flips `movie.id` / `mediaType`. Episode is always scoped for hubs;
  /// [audioCategory] splits SUB/DUB when set.
  static String cacheKey({
    required int mediaId,
    required String mediaType,
    int? season,
    int? episode,
    MetaOpen? open,
    String? pluginId,
    String? metaId,
    int? malId,
    String? audioCategory,
    String? episodeVideoId,
  }) {
    final ep = (episode == null || episode < 1) ? 1 : episode;
    final audio = (audioCategory ?? '').trim().toLowerCase();
    final audioSuffix =
        (audio == 'sub' || audio == 'dub') ? ':$audio' : '';

    final resolvedOpen = open;
    if (resolvedOpen != null) {
      final pid = (pluginId ?? '').trim();
      return metaOpenCacheKey(
        resolvedOpen,
        pluginId: pid.isNotEmpty ? pid : 'catalog',
        episode: ep,
        audioCategory: audioCategory,
        episodeVideoId: episodeVideoId,
      );
    }

    final pid = (pluginId ?? '').trim();
    final mid = (metaId ?? '').trim();
    if (pid.isNotEmpty && mid.isNotEmpty) {
      final vid = (episodeVideoId ?? '').trim();
      final vidSuffix = vid.isNotEmpty ? ':$vid' : '';
      return 'catalog:$pid:$mid:E$ep$audioSuffix$vidSuffix';
    }

    final type = mediaType == 'series' ? 'tv' : mediaType;
    if (type != 'tv') return '$type:$mediaId';
    final s = (season == null || season < 1) ? 1 : season;
    return '$type:$mediaId:S$s:E$ep';
  }

  static ({List<TorrentResult> results, Set<String> fetchedProviderIds})?
  readTorrents(String key) {
    final entry = _torrents[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.at) > streamTtl) {
      _torrents.remove(key);
      return null;
    }
    // Empty hits are not reusable — scrapers flake; force a fresh search.
    if (entry.results.isEmpty) {
      _torrents.remove(key);
      return null;
    }
    return (
      results: List<TorrentResult>.from(entry.results),
      fetchedProviderIds: Set<String>.from(entry.fetchedProviderIds),
    );
  }

  static void writeTorrents(
    String key,
    List<TorrentResult> results, {
    Set<String> fetchedProviderIds = const {},
  }) {
    if (results.isEmpty) {
      _torrents.remove(key);
      return;
    }
    _torrents[key] = (
      at: DateTime.now(),
      results: List.from(results),
      fetchedProviderIds: Set<String>.from(fetchedProviderIds),
    );
    _trim(_torrents);
  }

  static List<Map<String, dynamic>>? readStremio(String key) {
    final entry = _stremio[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.at) > streamTtl) {
      _stremio.remove(key);
      return null;
    }
    if (entry.streams.isEmpty) {
      _stremio.remove(key);
      return null;
    }
    return [for (final s in entry.streams) Map<String, dynamic>.from(s)];
  }

  static void writeStremio(String key, List<Map<String, dynamic>> streams) {
    if (streams.isEmpty) {
      _stremio.remove(key);
      return;
    }
    _stremio[key] = (
      at: DateTime.now(),
      streams: [for (final s in streams) Map<String, dynamic>.from(s)],
    );
    _trim(_stremio);
  }

  static ({List<Map<String, dynamic>> streams, Set<String> fetchedScraperIds})?
  readNuvio(String key) {
    final entry = _nuvio[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.at) > streamTtl) {
      _nuvio.remove(key);
      return null;
    }
    if (entry.streams.isEmpty && entry.fetchedScraperIds.isEmpty) {
      _nuvio.remove(key);
      return null;
    }
    return (
      streams: [for (final s in entry.streams) Map<String, dynamic>.from(s)],
      fetchedScraperIds: Set<String>.from(entry.fetchedScraperIds),
    );
  }

  static void writeNuvio(
    String key,
    List<Map<String, dynamic>> streams, {
    required Set<String> fetchedScraperIds,
  }) {
    if (streams.isEmpty && fetchedScraperIds.isEmpty) {
      _nuvio.remove(key);
      return;
    }
    final copied = [for (final s in streams) Map<String, dynamic>.from(s)];
    _nuvio[key] = (
      at: DateTime.now(),
      streams: copied,
      // Keep empty-miss markers so reopen does not re-hit every dead scraper.
      fetchedScraperIds: Set<String>.from(fetchedScraperIds),
    );
    _trim(_nuvio);
  }

  static ({List<Map<String, dynamic>> streams, Set<String> fetchedPluginIds})?
  readEngine(String key) {
    final entry = _engine[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.at) > streamTtl) {
      _engine.remove(key);
      return null;
    }
    if (entry.streams.isEmpty && entry.fetchedPluginIds.isEmpty) {
      _engine.remove(key);
      return null;
    }
    return (
      streams: [for (final s in entry.streams) Map<String, dynamic>.from(s)],
      fetchedPluginIds: Set<String>.from(entry.fetchedPluginIds),
    );
  }

  static void writeEngine(
    String key,
    List<Map<String, dynamic>> streams, {
    required Set<String> fetchedPluginIds,
  }) {
    if (streams.isEmpty && fetchedPluginIds.isEmpty) {
      _engine.remove(key);
      return;
    }
    final copied = [for (final s in streams) Map<String, dynamic>.from(s)];
    _engine[key] = (
      at: DateTime.now(),
      streams: copied,
      fetchedPluginIds: Set<String>.from(fetchedPluginIds),
    );
    _trim(_engine);
  }

  static CatalogSourcesPanelUiState? readUi(String key) {
    final entry = _ui[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.at) > streamTtl) {
      _ui.remove(key);
      return null;
    }
    return entry.state;
  }

  static void writeUi(String key, CatalogSourcesPanelUiState state) {
    _ui[key] = (at: DateTime.now(), state: state);
    _trim(_ui);
  }

  /// Stable key for a Sources-panel hover probe (HTTP stream URL only).
  static String? probeKeyForStream(Map<String, dynamic> stream) {
    final url = (stream['url'] ?? '').toString().trim();
    if (url.isEmpty) return null;
    final lower = url.toLowerCase();
    if (lower.startsWith('magnet:') ||
        lower.startsWith('stremio://') ||
        lower.startsWith('debrid:')) {
      return null;
    }
    return url;
  }

  static bool? readProbeHealth(String? probeKey) {
    final key = (probeKey ?? '').trim();
    if (key.isEmpty) return null;
    final entry = _probeHealth[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.at) > probeHealthTtl) {
      _probeHealth.remove(key);
      return null;
    }
    return entry.ok;
  }

  static void writeProbeHealth(String? probeKey, bool ok) {
    final key = (probeKey ?? '').trim();
    if (key.isEmpty) return;
    _probeHealth[key] = (at: DateTime.now(), ok: ok);
    _trim(_probeHealth);
  }

  /// Restores stream rows + fetched markers when RAM was cleared but TTL cache remains.
  static bool hydrateEngineIfEmpty({
    required String key,
    required List<Map<String, dynamic>> currentStreams,
    required void Function(
      List<Map<String, dynamic>> streams,
      Set<String> fetchedPluginIds,
    )
    apply,
  }) {
    if (currentStreams.isNotEmpty) return false;
    final cached = readEngine(key);
    if (cached == null) return false;
    apply(
      [for (final s in cached.streams) Map<String, dynamic>.from(s)],
      Set<String>.from(cached.fetchedPluginIds),
    );
    return true;
  }

  static bool hydrateNuvioIfEmpty({
    required String key,
    required List<Map<String, dynamic>> currentStreams,
    required void Function(
      List<Map<String, dynamic>> streams,
      Set<String> fetchedScraperIds,
    )
    apply,
  }) {
    if (currentStreams.isNotEmpty) return false;
    final cached = readNuvio(key);
    if (cached == null) return false;
    apply(
      [for (final s in cached.streams) Map<String, dynamic>.from(s)],
      Set<String>.from(cached.fetchedScraperIds),
    );
    return true;
  }

  /// Drop one kind (`torrents` | `stremio` | `nuvio` | `engine`) or all kinds for [key].
  static void invalidate(String key, {String? kind}) {
    switch (kind) {
      case 'torrents':
        _torrents.remove(key);
      case 'stremio':
        _stremio.remove(key);
      case 'nuvio':
        _nuvio.remove(key);
      case 'engine':
        _engine.remove(key);
      default:
        _torrents.remove(key);
        _stremio.remove(key);
        _nuvio.remove(key);
        _engine.remove(key);
        _ui.remove(key);
        // Probe health is URL-global; leave it (TTL / clearAll still purge).
    }
  }

  /// Drop every title session — pack install / local script edits must not leave
  /// green Play trusting empty `fetchedPluginIds` from the previous pack.
  static void clearAll() {
    _torrents.clear();
    _stremio.clear();
    _nuvio.clear();
    _engine.clear();
    _ui.clear();
    _probeHealth.clear();
  }

  static void _trim<T>(Map<String, T> map) {
    while (map.length > _maxEntriesPerKind) {
      map.remove(map.keys.first);
    }
  }
}
