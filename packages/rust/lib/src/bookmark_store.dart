import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_data_scope.dart';

typedef BookmarkSyncAddHandler = void Function(
  int? tmdbId,
  String? imdbId,
  String mediaType,
);

typedef BookmarkSyncRemoveHandler = void Function(
  int? tmdbId,
  String? imdbId,
  String mediaType,
);

/// Host bookmark persist engine — opaque rows + change notify.
/// Tracker sync via [syncAddHandler] / [syncRemoveHandler] from the host app.
class BookmarkStore {
  static final BookmarkStore _instance = BookmarkStore._internal();
  factory BookmarkStore() => _instance;
  BookmarkStore._internal() {
    LocalDataScope.addListener(_onScopeChanged);
    _init();
  }

  BookmarkSyncAddHandler? syncAddHandler;
  BookmarkSyncRemoveHandler? syncRemoveHandler;

  /// Opaque storage key (legacy id — do not treat as a pack contract).
  static const String _baseKey = 'my_list_items';
  String get _key => LocalDataScope.storageKey(_baseKey);

  final _controller = StreamController<List<Map<String, dynamic>>>.broadcast();
  List<Map<String, dynamic>> _items = [];
  bool _loaded = false;

  Stream<List<Map<String, dynamic>>> get stream => _controller.stream;
  List<Map<String, dynamic>> get items => List.unmodifiable(_items);
  static final ValueNotifier<int> changeNotifier = ValueNotifier<int>(0);

  Future<void> _onScopeChanged() async {
    _loaded = false;
    _items = [];
    await _init();
    _controller.add(List<Map<String, dynamic>>.from(_items));
    changeNotifier.value++;
  }

  Future<void> _init() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        _items = List<Map<String, dynamic>>.from(
          (json.decode(raw) as List).map((e) => Map<String, dynamic>.from(e)),
        );
      } catch (e) {
        debugPrint('[BookmarkStore] Failed to decode: $e');
        _items = [];
      }
    }
    _loaded = true;
    _notify();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, json.encode(_items));
    _notify();
  }

  void _notify() {
    _controller.add(List.unmodifiable(_items));
    changeNotifier.value++;
  }

  static String movieId(int tmdbId, String mediaType) =>
      'tmdb_${normalizeTmdbMediaType(mediaType) ?? mediaType}_$tmdbId';

  /// `movie` / `tv` for TMDB alias keys; null for anime / other hubs.
  static String? normalizeTmdbMediaType(String? raw) {
    final m = (raw ?? '').trim().toLowerCase();
    if (m == 'tv' || m == 'series' || m == 'shows' || m == 'drama') {
      return 'tv';
    }
    if (m == 'movie' || m == 'movies' || m == 'film' || m == 'films') {
      return 'movie';
    }
    return null;
  }

  /// Parse `tmdb_movie_123` / `tmdb_tv_456` → (id, mediaType).
  static (int, String)? parseMovieId(String uniqueId) {
    final m = RegExp(r'^tmdb_(movie|tv)_(\d+)$').firstMatch(uniqueId);
    if (m == null) return null;
    final id = int.tryParse(m.group(2)!);
    if (id == null) return null;
    return (id, m.group(1)!);
  }

  static String stremioItemId(Map<String, dynamic> item) {
    final id = item['imdb_id']?.toString() ??
        item['imdbId']?.toString() ??
        item['id']?.toString() ??
        item['name']?.toString() ??
        '';
    final type = item['type']?.toString() ?? 'unknown';
    return 'stremio_${type}_$id';
  }

  bool contains(String uniqueId) {
    return _items.any((e) => e['uniqueId'] == uniqueId);
  }

  static const defaultStatus = 'plantowatch';

  Future<void> ensureLoaded() => _ensureLoaded();

  String statusOf(String uniqueId) {
    for (final e in _items) {
      if (e['uniqueId'] == uniqueId) {
        return e['listStatus']?.toString() ?? defaultStatus;
      }
    }
    return defaultStatus;
  }

  Map<String, dynamic>? itemOf(String uniqueId) {
    for (final e in _items) {
      if (e['uniqueId'] == uniqueId) return Map<String, dynamic>.from(e);
    }
    return null;
  }

  /// Exact [uniqueId], or TMDB alias (`tmdb_*` ↔ catalog row with same tmdbId).
  Map<String, dynamic>? resolve({
    required String uniqueId,
    int? tmdbId,
    String? mediaType,
  }) {
    final exact = itemOf(uniqueId);
    if (exact != null) return exact;

    var tid = tmdbId;
    var wantMt = normalizeTmdbMediaType(mediaType);
    final parsed = parseMovieId(uniqueId);
    if (parsed != null) {
      tid ??= parsed.$1;
      wantMt ??= parsed.$2;
    }
    if (tid == null) return null;
    if (wantMt != null && wantMt != 'movie' && wantMt != 'tv') return null;

    if (wantMt == 'movie' || wantMt == 'tv') {
      final byKey = itemOf(movieId(tid, wantMt!));
      if (byKey != null) return byKey;
    }

    Map<String, dynamic>? loose;
    for (final e in _items) {
      final raw = e['tmdbId'];
      final id = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
      if (id != tid) continue;
      final rowMt = normalizeTmdbMediaType(
        e['tmdbMediaType']?.toString() ?? e['mediaType']?.toString(),
      );
      if (rowMt != 'movie' && rowMt != 'tv') continue;
      if (wantMt != null && rowMt != wantMt) continue;
      if (wantMt != null && rowMt == wantMt) {
        return Map<String, dynamic>.from(e);
      }
      loose ??= Map<String, dynamic>.from(e);
    }
    return loose;
  }

  bool hasEntry({
    required String uniqueId,
    int? tmdbId,
    String? mediaType,
  }) =>
      resolve(uniqueId: uniqueId, tmdbId: tmdbId, mediaType: mediaType) !=
      null;

  /// Null when not in any list; otherwise stored status (or [defaultStatus]).
  String? resolvedStatus({
    required String uniqueId,
    int? tmdbId,
    String? mediaType,
  }) {
    final row =
        resolve(uniqueId: uniqueId, tmdbId: tmdbId, mediaType: mediaType);
    if (row == null) return null;
    return row['listStatus']?.toString() ?? defaultStatus;
  }

  static String catalogEntryId(String pluginId, String openId) =>
      'catalog_${pluginId}_$openId';

  /// Drop sibling rows that share TMDB identity with [keepUniqueId].
  void _dropTmdbAliases({
    required String keepUniqueId,
    required int tmdbId,
    required String mediaType,
  }) {
    final mt = normalizeTmdbMediaType(mediaType);
    if (mt == null) return;
    final mid = movieId(tmdbId, mt);
    _items.removeWhere((e) {
      final uid = e['uniqueId']?.toString() ?? '';
      if (uid == keepUniqueId) return false;
      if (uid == mid) return true;
      final raw = e['tmdbId'];
      final id = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
      if (id != tmdbId) return false;
      final rowMt = normalizeTmdbMediaType(
        e['tmdbMediaType']?.toString() ?? e['mediaType']?.toString(),
      );
      return rowMt == mt;
    });
  }

  Future<void> upsertCatalog({
    required String pluginId,
    required Map<String, dynamic> open,
    required String uniqueId,
    required String mediaType,
    required String title,
    required String posterPath,
    required String listStatus,
    int? tmdbId,
    String? tmdbMediaType,
    double voteAverage = 0,
    String releaseDate = '',
  }) async {
    await _ensureLoaded();
    final aliasMt = normalizeTmdbMediaType(tmdbMediaType ?? mediaType);
    final existing = resolve(
      uniqueId: uniqueId,
      tmdbId: tmdbId,
      mediaType: aliasMt ?? mediaType,
    );
    final row = <String, dynamic>{
      ...?existing,
      'uniqueId': uniqueId,
      'pluginId': pluginId,
      'metaOpen': open,
      'catalogOpen': open,
      'open': open,
      'title': title,
      'posterPath': posterPath,
      'mediaType': mediaType,
      'voteAverage': voteAverage,
      'releaseDate': releaseDate,
      'source': pluginId,
      'listStatus': listStatus,
      'tmdbId': ?tmdbId,
      'tmdbMediaType': ?tmdbMediaType,
      'addedAt':
          existing?['addedAt'] ?? DateTime.now().millisecondsSinceEpoch,
    };
    // Drop legacy first-class pack id fields — opaque open only.
    row.remove('anilistId');
    row.remove('kisskhId');
    _items.removeWhere((e) => e['uniqueId'] == uniqueId);
    if (tmdbId != null && aliasMt != null) {
      _dropTmdbAliases(
        keepUniqueId: uniqueId,
        tmdbId: tmdbId,
        mediaType: aliasMt,
      );
    }
    _items.insert(0, row);
    await _save();
  }

  Future<void> upsertHub({
    required String uniqueId,
    required String mediaType,
    required String title,
    required String posterPath,
    required String listStatus,
    Map<String, dynamic>? open,
    int? tmdbId,
    String? tmdbMediaType,
    String? imdbId,
    double voteAverage = 0,
    String releaseDate = '',
  }) async {
    await _ensureLoaded();
    final idx = _items.indexWhere((e) => e['uniqueId'] == uniqueId);
    final row = <String, dynamic>{
      if (idx >= 0) ..._items[idx],
      'uniqueId': uniqueId,
      'title': title,
      'posterPath': posterPath,
      'mediaType': mediaType,
      'voteAverage': voteAverage,
      'releaseDate': releaseDate,
      'source': mediaType,
      'listStatus': listStatus,
      'tmdbId': ?tmdbId,
      'tmdbMediaType': ?tmdbMediaType,
      'imdbId': ?imdbId,
      if (open != null) ...{
        'metaOpen': open,
        'catalogOpen': open,
        'open': open,
      },
      'addedAt': idx >= 0
          ? _items[idx]['addedAt']
          : DateTime.now().millisecondsSinceEpoch,
    };
    row.remove('anilistId');
    row.remove('kisskhId');
    row.remove('kissKhType');
    if (idx >= 0) _items.removeAt(idx);
    _items.insert(0, row);
    final aliasTmdb = tmdbId;
    final aliasMt = normalizeTmdbMediaType(tmdbMediaType ?? mediaType);
    if (aliasTmdb != null && aliasMt != null) {
      _dropTmdbAliases(
        keepUniqueId: uniqueId,
        tmdbId: aliasTmdb,
        mediaType: aliasMt,
      );
    }
    await _save();
  }

  Future<void> upsertMovie({
    required int tmdbId,
    String? imdbId,
    required String title,
    required String posterPath,
    required String mediaType,
    double voteAverage = 0,
    String releaseDate = '',
    required String listStatus,
  }) async {
    await _ensureLoaded();
    final mt = normalizeTmdbMediaType(mediaType) ?? mediaType;
    final uid = movieId(tmdbId, mt);
    final existing = resolve(uniqueId: uid, tmdbId: tmdbId, mediaType: mt);
    final row = <String, dynamic>{
      ...?existing,
      'uniqueId': uid,
      'tmdbId': tmdbId,
      'imdbId': imdbId ?? existing?['imdbId'],
      'title': title,
      'posterPath': posterPath,
      'mediaType': mt,
      'voteAverage': voteAverage,
      'releaseDate': releaseDate,
      'source': 'tmdb',
      'listStatus': listStatus,
      'addedAt': existing?['addedAt'] ?? DateTime.now().millisecondsSinceEpoch,
    };
    // Preserve catalog open handoff when collapsing a catalog_* sibling.
    if (existing != null && existing['uniqueId'] != uid) {
      for (final k in ['pluginId', 'metaOpen', 'catalogOpen', 'open']) {
        if (row[k] == null && existing[k] != null) row[k] = existing[k];
      }
    }
    _items.removeWhere((e) => e['uniqueId'] == uid);
    _dropTmdbAliases(keepUniqueId: uid, tmdbId: tmdbId, mediaType: mt);
    _items.insert(0, row);
    await _save();
  }

  Future<void> addMovie({
    required int tmdbId,
    String? imdbId,
    required String title,
    required String posterPath,
    required String mediaType,
    double voteAverage = 0,
    String releaseDate = '',
  }) async {
    await _ensureLoaded();
    final mt = normalizeTmdbMediaType(mediaType) ?? mediaType;
    final uid = movieId(tmdbId, mt);
    if (hasEntry(uniqueId: uid, tmdbId: tmdbId, mediaType: mt)) return;
    _items.insert(0, {
      'uniqueId': uid,
      'tmdbId': tmdbId,
      'imdbId': imdbId,
      'title': title,
      'posterPath': posterPath,
      'mediaType': mt,
      'voteAverage': voteAverage,
      'releaseDate': releaseDate,
      'source': 'tmdb',
      'listStatus': defaultStatus,
      'addedAt': DateTime.now().millisecondsSinceEpoch,
    });
    await _save();
    syncAddHandler?.call(tmdbId, imdbId, mt);
  }

  Future<void> addStremioItem(Map<String, dynamic> item) async {
    await _ensureLoaded();
    final uid = stremioItemId(item);
    if (contains(uid)) return;
    _items.insert(0, {
      'uniqueId': uid,
      'tmdbId': null,
      'imdbId': item['imdb_id'] ?? item['imdbId'] ?? item['id'],
      'title': item['name']?.toString() ?? 'Unknown',
      'posterPath': item['poster']?.toString() ?? '',
      'mediaType': item['type']?.toString() ?? 'movie',
      'voteAverage': double.tryParse(item['imdbRating']?.toString() ?? '') ?? 0,
      'releaseDate': item['releaseInfo']?.toString() ?? '',
      'source': 'stremio',
      'stremioType': item['type']?.toString(),
      'listStatus': defaultStatus,
      'addedAt': DateTime.now().millisecondsSinceEpoch,
    });
    await _save();
    final imdb = item['imdb_id']?.toString() ?? item['imdbId']?.toString();
    syncAddHandler?.call(null, imdb, item['type']?.toString() ?? 'movie');
  }

  Future<void> remove(
    String uniqueId, {
    int? tmdbId,
    String? mediaType,
  }) async {
    await _ensureLoaded();
    final item = resolve(
          uniqueId: uniqueId,
          tmdbId: tmdbId,
          mediaType: mediaType,
        ) ??
        itemOf(uniqueId);
    final tid = item?['tmdbId'] as int? ?? tmdbId;
    final imdbId = item?['imdbId']?.toString();
    final mt = item?['tmdbMediaType']?.toString() ??
        item?['mediaType']?.toString() ??
        mediaType ??
        'movie';
    final keepGone = <String>{
      if (item != null) item['uniqueId']?.toString() ?? '',
      uniqueId,
    }..removeWhere((s) => s.isEmpty);
    _items.removeWhere((e) => keepGone.contains(e['uniqueId']?.toString()));
    if (tid != null) {
      final aliasMt = normalizeTmdbMediaType(mt);
      if (aliasMt != null) {
        _dropTmdbAliases(
          keepUniqueId: '', // drop all aliases
          tmdbId: tid,
          mediaType: aliasMt,
        );
      }
    }
    await _save();
    syncRemoveHandler?.call(tid, imdbId, mt);
  }

  Future<bool> toggleMovie({
    required int tmdbId,
    String? imdbId,
    required String title,
    required String posterPath,
    required String mediaType,
    double voteAverage = 0,
    String releaseDate = '',
  }) async {
    final mt = normalizeTmdbMediaType(mediaType) ?? mediaType;
    final uid = movieId(tmdbId, mt);
    if (hasEntry(uniqueId: uid, tmdbId: tmdbId, mediaType: mt)) {
      await remove(uid, tmdbId: tmdbId, mediaType: mt);
      return false;
    }
    await addMovie(
      tmdbId: tmdbId,
      imdbId: imdbId,
      title: title,
      posterPath: posterPath,
      mediaType: mt,
      voteAverage: voteAverage,
      releaseDate: releaseDate,
    );
    return true;
  }

  Future<bool> toggleStremioItem(Map<String, dynamic> item) async {
    final uid = stremioItemId(item);
    if (contains(uid)) {
      await remove(uid);
      return false;
    }
    await addStremioItem(item);
    return true;
  }

  Future<void> _ensureLoaded() async {
    if (!_loaded) await _init();
  }

  /// Test-only — empty in-memory rows without touching prefs listeners.
  @visibleForTesting
  void clearForTest() {
    _items = [];
    _loaded = true;
    changeNotifier.value++;
  }
}
