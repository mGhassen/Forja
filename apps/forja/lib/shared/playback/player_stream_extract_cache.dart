import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/ids.dart';
import 'package:forja/shared/playback/playback_stream_guards.dart';
import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cached resolved HTTP stream rows for a title (and TV episode).
class PlayerStreamExtractHit {
  const PlayerStreamExtractHit({
    required this.providerId,
    required this.sources,
  });

  final String providerId;
  final List<StreamSource> sources;
}

/// Engine chips (`engine:videasy`) and legacy registry provider ids.
bool isPlayerStreamExtractCacheProviderId(String providerId) {
  final pid = providerId.trim();
  if (pid.isEmpty) return false;
  return isWebStreamProviderId(pid) || EngineIds.isPluginChip(pid);
}

/// Session + disk cache of last working provider extract for player resume
/// and in-player provider/server switches (not WebView sniffing).
class PlayerStreamExtractCache {
  PlayerStreamExtractCache._();

  static const _diskKey = 'forja_player_stream_extract_cache_v1';
  static const _legacyDiskKey = 'forja_webstreaming_stream_cache_v1';
  static const _diskMaxEntries = 24;

  /// CDN links and signed HLS tokens go stale fast.
  static const _diskMaxAge = Duration(minutes: 25);
  static const _sessionTtl = Duration(minutes: 25);
  static const _sessionMaxEntries = 32;

  static final _session =
      <String, ({DateTime at, PlayerStreamExtractHit hit})>{};

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

  static bool isValidHit(PlayerStreamExtractHit hit) {
    if (!isPlayerStreamExtractCacheProviderId(hit.providerId)) return false;
    if (hit.sources.isEmpty) return false;
    return hit.sources.every(
      (s) =>
          s.url.trim().isNotEmpty &&
          !isTorrentStreamUrl(s.url) &&
          !isUnplayableCachedStreamUrl(s.url),
    );
  }

  static PlayerStreamExtractHit? _validated(PlayerStreamExtractHit? hit) {
    if (hit == null) return null;
    if (isValidHit(hit)) return hit;
    if (kDebugMode) {
      final first = hit.sources.isNotEmpty ? hit.sources.first.url : '';
      debugPrint(
        '[PlayerStreamExtractCache] rejected invalid hit '
        'provider=${hit.providerId} url=$first',
      );
    }
    return null;
  }

  static PlayerStreamExtractHit? readSession(String key) {
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

  static void writeSession(String key, PlayerStreamExtractHit hit) {
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

  static Future<PlayerStreamExtractHit?> readDisk(String key) async {
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
        PlayerStreamExtractHit(providerId: providerId, sources: sources),
      );
      if (hit == null) {
        await _purgeDiskKey(key);
        return null;
      }
      if (kDebugMode) {
        debugPrint(
          '[PlayerStreamExtractCache] disk hit $key (${hit.sources.length})',
        );
      }
      return hit;
    }
    return null;
  }

  static Future<void> writeDisk(String key, PlayerStreamExtractHit hit) async {
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

  static Future<void> clearAll() async {
    _session.clear();
    final p = await SharedPreferences.getInstance();
    await p.remove(_diskKey);
    await p.remove(_legacyDiskKey);
    if (kDebugMode) {
      debugPrint('[PlayerStreamExtractCache] cleared all entries');
    }
  }

  /// Memory first, then disk. Promotes disk hits into the session store.
  static Future<PlayerStreamExtractHit?> read(String key) async {
    final mem = readSession(key);
    if (mem != null) {
      if (kDebugMode) {
        debugPrint('[PlayerStreamExtractCache] session hit $key');
      }
      return mem;
    }
    final disk = await readDisk(key);
    if (disk != null) writeSession(key, disk);
    return disk;
  }

  /// [read] then [probe] the first source. Drops the entry when the CDN is dead
  /// (expired token, CF 403 segments, …) so callers fall through to re-resolve.
  static Future<PlayerStreamExtractHit?> readLive(
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
          '[PlayerStreamExtractCache] live probe failed - drop $key '
          '(${first.url})',
        );
      }
      await drop(key);
      return null;
    }
    return hit;
  }

  static Future<void> write(String key, PlayerStreamExtractHit hit) async {
    final validated = _validated(hit);
    if (validated == null) return;
    writeSession(key, validated);
    await writeDisk(key, validated);
  }

  static List<Map<String, dynamic>> _parseDiskList(List<String> raw) {
    final cutoff =
        DateTime.now().millisecondsSinceEpoch - _diskMaxAge.inMilliseconds;
    return raw
        .map((e) => jsonDecode(e) as Map<String, dynamic>)
        .where((e) => (e['t'] as int? ?? 0) >= cutoff)
        .toList();
  }

  static Future<List<Map<String, dynamic>>> _loadDisk() async {
    final p = await SharedPreferences.getInstance();
    var list = _parseDiskList(p.getStringList(_diskKey) ?? []);
    if (list.isEmpty) {
      list = _parseDiskList(p.getStringList(_legacyDiskKey) ?? []);
    }
    final rawCount =
        (p.getStringList(_diskKey) ?? []).length +
        (p.getStringList(_legacyDiskKey) ?? []).length;
    if (list.length != rawCount && list.isNotEmpty) {
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
    await p.remove(_legacyDiskKey);
  }
}
