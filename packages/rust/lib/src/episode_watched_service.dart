import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_data_scope.dart';
import 'watch_history_resume.dart';

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
/// Only unscoped (TMDB) toggles invoke [syncHandler]. Catalog-scoped
/// keys (`anilist_…`, `kisskh_…`) stay local-only.
class EpisodeWatchedService {
  static final EpisodeWatchedService _instance = EpisodeWatchedService._();
  factory EpisodeWatchedService() => _instance;
  EpisodeWatchedService._() {
    LocalDataScope.addListener(_onScopeChanged);
  }

  /// AniList anime details — local marks only.
  static const String catalogAnilist = 'anilist';

  /// KissKH Asian Drama details — local marks only.
  static const String catalogKisskh = 'kisskh';

  EpisodeWatchedSyncHandler? syncHandler;

  static const String _baseKey = 'episodes_watched';
  static const String _baseTimestampKey = 'episodes_watched_timestamps';
  String get _key => LocalDataScope.storageKey(_baseKey);
  String get _timestampKey => LocalDataScope.storageKey(_baseTimestampKey);

  Map<String, bool>? _cache;

  Future<void> _onScopeChanged() async {
    _cache = null;
    _timestampCache = null;
  }

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

  /// TMDB: `{id}_S{s}_E{e}`. Catalog hubs: `{catalog}_{id}_S{s}_E{e}`.
  String _id(int mediaId, int season, int episode, {String? catalog}) {
    final base = '${mediaId}_S${season}_E$episode';
    if (catalog == null || catalog.isEmpty) return base;
    return '${catalog}_$base';
  }

  String _mediaPrefix(int mediaId, {String? catalog}) {
    if (catalog == null || catalog.isEmpty) return '${mediaId}_';
    return '${catalog}_${mediaId}_';
  }

  Future<bool> isWatched(
    int mediaId,
    int season,
    int episode, {
    String? catalog,
  }) async {
    final map = await _load();
    return map[_id(mediaId, season, episode, catalog: catalog)] == true;
  }

  Future<Set<String>> getWatchedSet(int mediaId, {String? catalog}) async {
    final map = await _load();
    final prefix = _mediaPrefix(mediaId, catalog: catalog);
    return map.keys.where((k) => k.startsWith(prefix) && map[k] == true).toSet();
  }

  Future<void> toggle(
    int mediaId,
    int season,
    int episode, {
    String? catalog,
  }) async {
    final map = await _load();
    final id = _id(mediaId, season, episode, catalog: catalog);
    final current = map[id] == true;
    map[id] = !current;
    await _save();
    debugPrint('[EpisodeWatched] ${!current ? "Marked" : "Unmarked"} $id');
    // Tracker sync is TMDB-only — hub catalogs have no Trakt/Simkl mapping.
    if (catalog == null || catalog.isEmpty) {
      _syncEpisodeState(mediaId, season, episode, !current);
    }
  }

  Future<void> setWatched(
    int mediaId,
    int season,
    int episode,
    bool watched, {
    String? catalog,
  }) async {
    final map = await _load();
    final id = _id(mediaId, season, episode, catalog: catalog);
    map[id] = watched;
    await _save();
    if (catalog == null || catalog.isEmpty) {
      _syncEpisodeState(mediaId, season, episode, watched);
    }
  }

  /// Mark or unmark every [episodes] entry in one save. If all are already
  /// watched, clears them; otherwise marks all watched. Returns the new state.
  Future<bool> toggleSeason(
    int mediaId,
    int season,
    List<int> episodes, {
    String? catalog,
  }) async {
    if (episodes.isEmpty) return false;
    final map = await _load();
    final allWatched = episodes.every(
      (e) => map[_id(mediaId, season, e, catalog: catalog)] == true,
    );
    final watched = !allWatched;
    for (final e in episodes) {
      map[_id(mediaId, season, e, catalog: catalog)] = watched;
    }
    await _save();
    debugPrint(
      '[EpisodeWatched] Season $season ${watched ? "marked" : "unmarked"} '
      '${episodes.length} episodes',
    );
    if (catalog == null || catalog.isEmpty) {
      for (final e in episodes) {
        _syncEpisodeState(mediaId, season, e, watched);
      }
    }
    return watched;
  }

  /// Auto-mark when playback hits [watchFinishedThreshold]. No-op if already
  /// watched. Manual unwatch sticks until the next ≥threshold save.
  Future<bool> markWatchedIfFinished({
    required int mediaId,
    required int season,
    required int episode,
    required int positionMs,
    required int durationMs,
    String? catalog,
  }) async {
    if (!isWatchFinished(positionMs, durationMs)) return false;
    final map = await _load();
    final id = _id(mediaId, season, episode, catalog: catalog);
    if (map[id] == true) return false;
    map[id] = true;
    await _save();
    debugPrint('[EpisodeWatched] Auto-marked $id (≥${(watchFinishedThreshold * 100).round()}%)');
    if (catalog == null || catalog.isEmpty) {
      _syncEpisodeState(mediaId, season, episode, true);
    }
    return true;
  }

  Future<void> setWatchedLocal(
    int mediaId,
    int season,
    int episode,
    bool watched, {
    String? catalog,
  }) async {
    final map = await _load();
    final id = _id(mediaId, season, episode, catalog: catalog);
    map[id] = watched;
    await _save();
  }

  Future<void> setWatchedLocalWithTimestamp(
    int mediaId,
    int season,
    int episode,
    bool watched,
    String? watchedAt, {
    String? catalog,
  }) async {
    final map = await _load();
    final id = _id(mediaId, season, episode, catalog: catalog);
    map[id] = watched;
    await _save();
    if (watchedAt != null && watched) {
      await _saveTimestamp(id, watchedAt);
    }
  }

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

  Future<String?> getTimestamp(
    int mediaId,
    int season,
    int episode, {
    String? catalog,
  }) async {
    final map = await _loadTimestamps();
    return map[_id(mediaId, season, episode, catalog: catalog)];
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
