import 'dart:convert';

import 'package:flutter/foundation.dart';
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
  static const _diskMaxAge = Duration(hours: 2);
  static const _sessionTtl = Duration(hours: 2);
  static const _sessionMaxEntries = 32;

  static final _session =
      <String, ({DateTime at, WebstreamingCacheHit hit})>{};

  static String cacheKey({
    required int tmdbId,
    required String mediaType,
    int season = 0,
    int episode = 0,
  }) {
    final isTv = mediaType == 'tv';
    return isTv
        ? '$mediaType:$tmdbId:S$season:E$episode'
        : '$mediaType:$tmdbId';
  }

  static WebstreamingCacheHit? readSession(String key) {
    final entry = _session[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.at) > _sessionTtl) {
      _session.remove(key);
      return null;
    }
    return entry.hit;
  }

  static void writeSession(String key, WebstreamingCacheHit hit) {
    if (hit.sources.isEmpty) return;
    _session[key] = (at: DateTime.now(), hit: hit);
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
        return null;
      }
      final sources = rawSources
          .map((s) => StreamSource.fromJson((s as Map).cast<String, dynamic>()))
          .where((s) => s.url.isNotEmpty)
          .toList();
      if (sources.isEmpty) return null;
      if (kDebugMode) {
        debugPrint('[WebstreamingCache] disk hit $key (${sources.length})');
      }
      return WebstreamingCacheHit(providerId: providerId, sources: sources);
    }
    return null;
  }

  static Future<void> writeDisk(String key, WebstreamingCacheHit hit) async {
    if (hit.sources.isEmpty) return;
    var list = await _loadDisk();
    list.removeWhere((e) => e['k'] == key);
    list.insert(0, {
      'k': key,
      't': DateTime.now().millisecondsSinceEpoch,
      'providerId': hit.providerId,
      'sources': hit.sources.map((s) => s.toJson()).toList(),
    });
    if (list.length > _diskMaxEntries) {
      list = list.sublist(0, _diskMaxEntries);
    }
    await _persistDisk(list);
  }

  static Future<void> dropDisk(String key) async {
    final list = await _loadDisk();
    if (!list.any((e) => e['k'] == key)) return;
    list.removeWhere((e) => e['k'] == key);
    await _persistDisk(list);
  }

  static Future<void> drop(String key) async {
    dropSession(key);
    await dropDisk(key);
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

  static Future<void> write(String key, WebstreamingCacheHit hit) async {
    writeSession(key, hit);
    await writeDisk(key, hit);
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
