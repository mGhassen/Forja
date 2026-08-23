import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/nuvio/nuvio_service.dart';
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
/// panel within [ttl] reuses the last fetch. Empty results and per-provider
/// misses are never stored — a flaky scraper or dead addon must not block retry.
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

  /// Stable key - TV always uses 1-based season/episode.
  static String cacheKey({
    required int mediaId,
    required String mediaType,
    int? season,
    int? episode,
  }) {
    final type = mediaType == 'series' ? 'tv' : mediaType;
    if (type != 'tv') return '$type:$mediaId';
    final s = (season == null || season < 1) ? 1 : season;
    final e = (episode == null || episode < 1) ? 1 : episode;
    return '$type:$mediaId:S$s:E$e';
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
    if (entry.streams.isEmpty) {
      _nuvio.remove(key);
      return null;
    }
    return (
      streams: [for (final s in entry.streams) Map<String, dynamic>.from(s)],
      fetchedScraperIds: _nuvioFetchedWithHits(entry.streams, entry.fetchedScraperIds),
    );
  }

  static void writeNuvio(
    String key,
    List<Map<String, dynamic>> streams, {
    required Set<String> fetchedScraperIds,
  }) {
    if (streams.isEmpty) {
      _nuvio.remove(key);
      return;
    }
    final copied = [for (final s in streams) Map<String, dynamic>.from(s)];
    _nuvio[key] = (
      at: DateTime.now(),
      streams: copied,
      fetchedScraperIds: _nuvioFetchedWithHits(copied, fetchedScraperIds),
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
    if (entry.streams.isEmpty) {
      _engine.remove(key);
      return null;
    }
    return (
      streams: [for (final s in entry.streams) Map<String, dynamic>.from(s)],
      fetchedPluginIds: _engineFetchedWithHits(entry.streams, entry.fetchedPluginIds),
    );
  }

  static void writeEngine(
    String key,
    List<Map<String, dynamic>> streams, {
    required Set<String> fetchedPluginIds,
  }) {
    if (streams.isEmpty) {
      _engine.remove(key);
      return;
    }
    final copied = [for (final s in streams) Map<String, dynamic>.from(s)];
    _engine[key] = (
      at: DateTime.now(),
      streams: copied,
      fetchedPluginIds: _engineFetchedWithHits(copied, fetchedPluginIds),
    );
    _trim(_engine);
  }

  static Set<String> _nuvioFetchedWithHits(
    Iterable<Map<String, dynamic>> streams,
    Set<String> fetchedScraperIds,
  ) => {
    for (final id in fetchedScraperIds)
      if (streams.any((s) => nuvioStreamBelongsToScraper(s, id))) id,
  };

  static Set<String> _engineFetchedWithHits(
    Iterable<Map<String, dynamic>> streams,
    Set<String> fetchedPluginIds,
  ) => {
    for (final id in fetchedPluginIds)
      if (enginePluginHasStreams(id, streams)) id,
  };

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
