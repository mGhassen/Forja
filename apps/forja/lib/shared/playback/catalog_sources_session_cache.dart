import 'package:flutter/foundation.dart';
import 'package:rust/rust.dart';

/// Tab, chip, and toolbar state for catalog Sources (player overlay).
///
/// Details keeps this on [DetailsPlaySession] while the route is mounted;
/// the player writes it here on dismiss so reopening Sources within [ttl]
/// restores the last tab/chips/filters for the same title/episode.
@immutable
class CatalogSourcesPanelUiState {
  const CatalogSourcesPanelUiState({
    required this.kindFilter,
    required this.selectedSourceId,
    required this.nuvioSelectedScraperIds,
    required this.engineSelectedPluginIds,
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

/// In-memory TTL cache for catalog Sources (Torrents / Stremio / Nuvio / Engine).
///
/// Shared by media-details and the in-player Sources panel so reopening the
/// panel within [ttl] reuses the last fetch. Torrents / Stremio still drop
/// empty lists (flaky search). Forja / Nuvio keep fetched markers even when a
/// scraper returned nothing so hub overlay reopen matches movie details RAM
/// (explicit kind/chip reload still force-refetches).
class CatalogSourcesSessionCache {
  CatalogSourcesSessionCache._();

  static const ttl = Duration(minutes: 30);
  static const _maxEntriesPerKind = 48;

  static final _torrents =
      <String, ({DateTime at, List<TorrentResult> results})>{};
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

  /// Stable key for a title/episode Sources session.
  ///
  /// Prefer hub ids ([anilistId] / [kisskhId]) so Anime / Asian Drama stay on
  /// one key when TMDB enrichment flips `movie.id` / `mediaType`. Episode is
  /// always scoped for hubs; [animeAudioCategory] splits SUB/DUB when set.
  static String cacheKey({
    required int mediaId,
    required String mediaType,
    int? season,
    int? episode,
    int? anilistId,
    int? malId,
    int? kisskhId,
    String? animeAudioCategory,
  }) {
    final ep = (episode == null || episode < 1) ? 1 : episode;
    final audio = (animeAudioCategory ?? '').trim().toLowerCase();
    final audioSuffix =
        (audio == 'sub' || audio == 'dub') ? ':$audio' : '';

    final ani = anilistId ?? 0;
    if (ani > 0) return 'anime:$ani:E$ep$audioSuffix';

    final kiss = kisskhId ?? 0;
    if (kiss > 0) return 'drama:$kiss:E$ep';

    // Fallback Movie builds use negative AniList / KissKh ids + hub mediaType
    // before TMDB lands — still episode-scoped (not bare `anime:-id`).
    final type = mediaType == 'series' ? 'tv' : mediaType;
    if (type == 'anime' || type == 'asian_drama' || type == 'drama') {
      final s = (season == null || season < 1) ? 1 : season;
      final mal = malId ?? 0;
      final malSuffix = mal > 0 ? ':mal$mal' : '';
      return '$type:$mediaId$malSuffix:S$s:E$ep$audioSuffix';
    }
    if (type != 'tv') return '$type:$mediaId';
    final s = (season == null || season < 1) ? 1 : season;
    return '$type:$mediaId:S$s:E$ep';
  }

  static List<TorrentResult>? readTorrents(String key) {
    final entry = _torrents[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.at) > ttl) {
      _torrents.remove(key);
      return null;
    }
    // Empty hits are not reusable — scrapers flake; force a fresh search.
    if (entry.results.isEmpty) {
      _torrents.remove(key);
      return null;
    }
    return List<TorrentResult>.from(entry.results);
  }

  static void writeTorrents(String key, List<TorrentResult> results) {
    if (results.isEmpty) {
      _torrents.remove(key);
      return;
    }
    _torrents[key] = (at: DateTime.now(), results: List.from(results));
    _trim(_torrents);
  }

  static List<Map<String, dynamic>>? readStremio(String key) {
    final entry = _stremio[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.at) > ttl) {
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
    if (DateTime.now().difference(entry.at) > ttl) {
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
    if (DateTime.now().difference(entry.at) > ttl) {
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
    if (DateTime.now().difference(entry.at) > ttl) {
      _ui.remove(key);
      return null;
    }
    return entry.state;
  }

  static void writeUi(String key, CatalogSourcesPanelUiState state) {
    _ui[key] = (at: DateTime.now(), state: state);
    _trim(_ui);
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
    }
  }

  static void _trim<T>(Map<String, T> map) {
    while (map.length > _maxEntriesPerKind) {
      map.remove(map.keys.first);
    }
  }
}
