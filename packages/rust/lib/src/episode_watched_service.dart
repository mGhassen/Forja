import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef EpisodeWatchedSyncHandler = void Function(
  int tmdbId,
  int season,
  int episode,
  bool watched,
);

/// Lightweight service to track which episodes the user has manually
/// marked as "done watching". Persisted via SharedPreferences so the
/// state is shared across *all* detail screens (torrent & streaming).
///
/// Optional [syncHandler] pushes changes to Trakt/Simkl — register from
/// the host app so this package stays free of `packages/api` imports.
class EpisodeWatchedService {
  static final EpisodeWatchedService _instance = EpisodeWatchedService._();
  factory EpisodeWatchedService() => _instance;
  EpisodeWatchedService._();

  EpisodeWatchedSyncHandler? syncHandler;

  static const String _key = 'episodes_watched';

  Map<String, bool>? _cache;

  Future<Map<String, bool>> _load() async {
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      _cache = decoded.map((k, v) => MapEntry(k, v == true));
    } else {
      _cache = {};
    }
    return _cache!;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, json.encode(_cache));
  }

  String _id(int tmdbId, int season, int episode) =>
      '${tmdbId}_S${season}_E$episode';

  Future<bool> isWatched(int tmdbId, int season, int episode) async {
    final map = await _load();
    return map[_id(tmdbId, season, episode)] == true;
  }

  Future<Set<String>> getWatchedSet(int tmdbId) async {
    final map = await _load();
    return map.keys
        .where((k) => k.startsWith('${tmdbId}_') && map[k] == true)
        .toSet();
  }

  Future<void> toggle(int tmdbId, int season, int episode) async {
    final map = await _load();
    final id = _id(tmdbId, season, episode);
    final current = map[id] == true;
    map[id] = !current;
    await _save();
    debugPrint('[EpisodeWatched] ${!current ? "Marked" : "Unmarked"} $id');
    _syncEpisodeState(tmdbId, season, episode, !current);
  }

  Future<void> setWatched(
    int tmdbId,
    int season,
    int episode,
    bool watched,
  ) async {
    final map = await _load();
    final id = _id(tmdbId, season, episode);
    map[id] = watched;
    await _save();
    _syncEpisodeState(tmdbId, season, episode, watched);
  }

  Future<void> setWatchedLocal(
    int tmdbId,
    int season,
    int episode,
    bool watched,
  ) async {
    final map = await _load();
    final id = _id(tmdbId, season, episode);
    map[id] = watched;
    await _save();
  }

  Future<void> setWatchedLocalWithTimestamp(
    int tmdbId,
    int season,
    int episode,
    bool watched,
    String? watchedAt,
  ) async {
    final map = await _load();
    final id = _id(tmdbId, season, episode);
    map[id] = watched;
    await _save();
    if (watchedAt != null && watched) {
      await _saveTimestamp(id, watchedAt);
    }
  }

  static const String _timestampKey = 'episodes_watched_timestamps';
  Map<String, String>? _timestampCache;

  Future<Map<String, String>> _loadTimestamps() async {
    if (_timestampCache != null) return _timestampCache!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_timestampKey);
    if (raw != null) {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      _timestampCache = decoded.map((k, v) => MapEntry(k, v.toString()));
    } else {
      _timestampCache = {};
    }
    return _timestampCache!;
  }

  Future<void> _saveTimestamp(String id, String watchedAt) async {
    final map = await _loadTimestamps();
    map[id] = watchedAt;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_timestampKey, json.encode(map));
  }

  Future<String?> getTimestamp(int tmdbId, int season, int episode) async {
    final map = await _loadTimestamps();
    return map[_id(tmdbId, season, episode)];
  }

  Future<Map<String, String>> getAllTimestamps() async {
    return await _loadTimestamps();
  }

  void _syncEpisodeState(int tmdbId, int season, int episode, bool watched) {
    syncHandler?.call(tmdbId, season, episode, watched);
  }

  /// Clear local watched checkmarks and timestamps (does not touch Trakt/Simkl).
  Future<void> clearAll() async {
    _cache = {};
    _timestampCache = {};
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_timestampKey);
    debugPrint('[EpisodeWatched] Cleared all local watched flags');
  }
}
