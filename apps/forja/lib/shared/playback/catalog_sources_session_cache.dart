import 'package:rust/rust.dart';

/// In-memory TTL cache for catalog Sources (Torrents / Stremio / Nuvio).
///
/// Shared by media-details and the in-player Sources panel so reopening the
/// panel within [ttl] reuses the last fetch instead of hammering scrapers.
class CatalogSourcesSessionCache {
  CatalogSourcesSessionCache._();

  static const ttl = Duration(minutes: 30);
  static const _maxEntriesPerKind = 48;

  static final _torrents =
      <String, ({DateTime at, List<TorrentResult> results})>{};
  static final _stremio =
      <String, ({DateTime at, List<Map<String, dynamic>> streams})>{};
  static final _nuvio =
      <String, ({DateTime at, List<Map<String, dynamic>> streams})>{};

  /// Stable key — TV always uses 1-based season/episode.
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
    return List<TorrentResult>.from(entry.results);
  }

  static void writeTorrents(String key, List<TorrentResult> results) {
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
    return [
      for (final s in entry.streams) Map<String, dynamic>.from(s),
    ];
  }

  static void writeStremio(String key, List<Map<String, dynamic>> streams) {
    _stremio[key] = (
      at: DateTime.now(),
      streams: [for (final s in streams) Map<String, dynamic>.from(s)],
    );
    _trim(_stremio);
  }

  static List<Map<String, dynamic>>? readNuvio(String key) {
    final entry = _nuvio[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.at) > ttl) {
      _nuvio.remove(key);
      return null;
    }
    return [
      for (final s in entry.streams) Map<String, dynamic>.from(s),
    ];
  }

  static void writeNuvio(String key, List<Map<String, dynamic>> streams) {
    _nuvio[key] = (
      at: DateTime.now(),
      streams: [for (final s in streams) Map<String, dynamic>.from(s)],
    );
    _trim(_nuvio);
  }

  /// Drop one kind (`torrents` | `stremio` | `nuvio`) or all kinds for [key].
  static void invalidate(String key, {String? kind}) {
    switch (kind) {
      case 'torrents':
        _torrents.remove(key);
      case 'stremio':
        _stremio.remove(key);
      case 'nuvio':
        _nuvio.remove(key);
      default:
        _torrents.remove(key);
        _stremio.remove(key);
        _nuvio.remove(key);
    }
  }

  static void _trim<T>(Map<String, T> map) {
    while (map.length > _maxEntriesPerKind) {
      map.remove(map.keys.first);
    }
  }
}
