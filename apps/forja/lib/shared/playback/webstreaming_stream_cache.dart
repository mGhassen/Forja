import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/playback/playback_stream_guards.dart';
import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cached webstreaming extract for a title (and TV episode).
class WebstreamingCacheHit {
  const WebstreamingCacheHit({
    required this.providerId,
    required this.sources,
  });

  final String providerId;
  final List<StreamSource> sources;
}

/// Session + disk cache so green Play reuses the last working extract
/// instead of re-racing providers when the user leaves and returns.
class WebstreamingStreamCache {
  WebstreamingStreamCache._();

  static const _diskKey = 'forja_webstreaming_stream_cache_v1';
  static const _diskMaxEntries = 24;
  /// Match anime stream cache - CloudStream JWT + CDN links go stale fast.
  static const _diskMaxAge = Duration(minutes: 25);
  static const _sessionTtl = Duration(minutes: 25);
  static const _sessionMaxEntries = 32;

  static final _session =
      <String, ({DateTime at, WebstreamingCacheHit hit})>{};

  /// Stable cache key - TV always uses 1-based season/episode.
  static String cacheKey({
    required int tmdbId,
    required String mediaType,
    int season = 0,
    int episode = 0,
  }) {
    final type = mediaType == 'series' ? 'tv' : mediaType;
    final isTv = type == 'tv';
    if (!isTv) return '$type:$tmdbId';
    final s = season < 1 ? 1 : season;
    final e = episode < 1 ? 1 : episode;
    return '$type:$tmdbId:S$s:E$e';
  }

  /// Build a key from watch-history / player fields (null-safe for TV).
  static String cacheKeyFromProgress({
    required int tmdbId,
    required String mediaType,
    int? season,
    int? episode,
  }) =>
      cacheKey(
        tmdbId: tmdbId,
        mediaType: mediaType,
        season: season ?? 1,
        episode: episode ?? 1,
      );

  static bool isValidHit(WebstreamingCacheHit hit) {
    if (!isWebStreamProviderId(hit.providerId)) return false;
    if (hit.sources.isEmpty) return false;
    return hit.sources.every(
      (s) =>
          s.url.trim().isNotEmpty &&
          !isTorrentStreamUrl(s.url) &&
          !isUnplayableCachedStreamUrl(s.url),
    );
  }

  static WebstreamingCacheHit? _validated(WebstreamingCacheHit? hit) {
    if (hit == null) return null;
    if (isValidHit(hit)) return hit;
    if (kDebugMode) {
      final first = hit.sources.isNotEmpty ? hit.sources.first.url : '';
      debugPrint(
        '[WebstreamingCache] rejected invalid hit '
        'provider=${hit.providerId} url=$first',
      );
    }
    return null;
  }

  static WebstreamingCacheHit? readSession(String key) {
    final entry = _session[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.at) > _sessionTtl) {
      _session.remove(key);
      return null;
    }
    final hit = _validated(entry.hit);
    if (hit == null) {
      _session.remove(key);
      return null;
    }
    return hit;
  }

  static void writeSession(String key, WebstreamingCacheHit hit) {
    final validated = _validated(hit);
    if (validated == null) return;
    _session[key] = (at: DateTime.now(), hit: validated);
    while (_session.length > _sessionMaxEntries) {
      String? oldestKey;
      DateTime? oldestAt;
      for (final e in _session.entries) {
        if (oldestAt == null || e.value.at.isBefore(oldestAt)) {
          oldestAt = e.value.at;
          oldestKey = e.key;
        }
      }
      if (oldestKey == null) break;
      _session.remove(oldestKey);
    }
  }

  static void dropSession(String key) => _session.remove(key);

  static Future<WebstreamingCacheHit?> readDisk(String key) async {
    final list = await _loadDisk();
    for (final e in list) {
      if (e['k'] != key) continue;
      final providerId = e['providerId'] as String? ?? '';
      final rawSources = e['sources'] as List?;
      if (providerId.isEmpty || rawSources == null || rawSources.isEmpty) {
        await _purgeDiskKey(key);
        return null;
      }
      final sources = rawSources
          .map((s) => StreamSource.fromJson((s as Map).cast<String, dynamic>()))
          .where((s) => s.url.isNotEmpty)
          .toList();
      final hit = _validated(
        WebstreamingCacheHit(providerId: providerId, sources: sources),
      );
      if (hit == null) {
        await _purgeDiskKey(key);
        return null;
      }
      if (kDebugMode) {
        debugPrint('[WebstreamingCache] disk hit $key (${hit.sources.length})');
      }
      return hit;
    }
    return null;
  }

  static Future<void> writeDisk(String key, WebstreamingCacheHit hit) async {
    final validated = _validated(hit);
    if (validated == null) return;
    var list = await _loadDisk();
    list.removeWhere((e) => e['k'] == key);
    list.insert(0, {
      'k': key,
      't': DateTime.now().millisecondsSinceEpoch,
      'providerId': validated.providerId,
      'sources': validated.sources.map((s) => s.toJson()).toList(),
    });
    if (list.length > _diskMaxEntries) {
      list = list.sublist(0, _diskMaxEntries);
    }
    await _persistDisk(list);
  }

  static Future<void> dropDisk(String key) async {
    await _purgeDiskKey(key);
  }

  static Future<void> _purgeDiskKey(String key) async {
    final list = await _loadDisk();
    if (!list.any((e) => e['k'] == key)) return;
    list.removeWhere((e) => e['k'] == key);
    await _persistDisk(list);
  }

  static Future<void> drop(String key) async {
    dropSession(key);
    await dropDisk(key);
  }

  /// Clears in-memory session entries and all persisted webstreaming cache.
  static Future<void> clearAll() async {
    _session.clear();
    final p = await SharedPreferences.getInstance();
    await p.remove(_diskKey);
    if (kDebugMode) {
      debugPrint('[WebstreamingCache] cleared all entries');
    }
  }

  /// Memory first, then disk. Promotes disk hits into the session store.
  static Future<WebstreamingCacheHit?> read(String key) async {
    final mem = readSession(key);
    if (mem != null) {
      if (kDebugMode) {
        debugPrint('[WebstreamingCache] session hit $key');
      }
      return mem;
    }
    final disk = await readDisk(key);
    if (disk != null) writeSession(key, disk);
    return disk;
  }

  /// [read] then [probe] the first source. Drops the entry when the CDN is dead
  /// (expired token, CF 403 segments, …) so callers fall through to re-resolve.
  static Future<WebstreamingCacheHit?> readLive(
    String key, {
    required Future<bool> Function(String url, Map<String, String>? headers)
        probe,
  }) async {
    final hit = await read(key);
    if (hit == null) return null;
    final first = hit.sources.first;
    final ok = await probe(first.url, first.headers);
    if (!ok) {
      if (kDebugMode) {
        debugPrint(
          '[WebstreamingCache] live probe failed - drop $key '
          '(${first.url})',
        );
      }
      await drop(key);
      return null;
    }
    return hit;
  }

  static Future<void> write(String key, WebstreamingCacheHit hit) async {
    final validated = _validated(hit);
    if (validated == null) return;
    writeSession(key, validated);
    await writeDisk(key, validated);
  }

  static Future<List<Map<String, dynamic>>> _loadDisk() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_diskKey) ?? [];
    final cutoff =
        DateTime.now().millisecondsSinceEpoch - _diskMaxAge.inMilliseconds;
    final list = raw
        .map((e) => jsonDecode(e) as Map<String, dynamic>)
        .where((e) => (e['t'] as int? ?? 0) >= cutoff)
        .toList();
    if (list.length != raw.length) {
      await _persistDisk(list);
    }
    return list;
  }

  static Future<void> _persistDisk(List<Map<String, dynamic>> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
      _diskKey,
      list.map(jsonEncode).toList(growable: false),
    );
  }
}
