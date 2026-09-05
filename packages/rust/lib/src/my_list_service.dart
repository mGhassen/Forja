import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_data_scope.dart';

typedef MyListSyncAddHandler = void Function(
  int? tmdbId,
  String? imdbId,
  String mediaType,
);

typedef MyListSyncRemoveHandler = void Function(
  int? tmdbId,
  String? imdbId,
  String mediaType,
);

/// Persisted "My List" — movies & shows the user bookmarks.
/// Trakt/Simkl sync via [syncAddHandler] / [syncRemoveHandler] from the host app.
class MyListService {
  static final MyListService _instance = MyListService._internal();
  factory MyListService() => _instance;
  MyListService._internal() {
    LocalDataScope.addListener(_onScopeChanged);
    _init();
  }

  MyListSyncAddHandler? syncAddHandler;
  MyListSyncRemoveHandler? syncRemoveHandler;

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
        debugPrint('[MyList] Failed to decode: $e');
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
      'tmdb_${mediaType}_$tmdbId';

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

  static String anilistId(int id) => 'anilist_$id';

  static String kisskhId(int id) => 'kisskh_$id';

  Map<String, dynamic>? itemOf(String uniqueId) {
    for (final e in _items) {
      if (e['uniqueId'] == uniqueId) return Map<String, dynamic>.from(e);
    }
    return null;
  }

  static String catalogEntryId(String pluginId, String openId) =>
      'catalog_${pluginId}_$openId';

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
    final idx = _items.indexWhere((e) => e['uniqueId'] == uniqueId);
    final row = <String, dynamic>{
      if (idx >= 0) ..._items[idx],
      'uniqueId': uniqueId,
      'pluginId': pluginId,
      'catalogOpen': open,
      'title': title,
      'posterPath': posterPath,
      'mediaType': mediaType,
      'voteAverage': voteAverage,
      'releaseDate': releaseDate,
      'source': pluginId,
      'listStatus': listStatus,
      'tmdbId': ?tmdbId,
      'tmdbMediaType': ?tmdbMediaType,
      'addedAt': idx >= 0
          ? _items[idx]['addedAt']
          : DateTime.now().millisecondsSinceEpoch,
    };
    if (idx >= 0) _items.removeAt(idx);
    _items.insert(0, row);
    await _save();
  }

  Future<void> upsertHub({
    required String uniqueId,
    required String mediaType,
    required String title,
    required String posterPath,
    required String listStatus,
    int? anilistId,
    int? kisskhId,
    int? tmdbId,
    String? tmdbMediaType,
    String? imdbId,
    double voteAverage = 0,
    String releaseDate = '',
    String? kissKhType,
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
      'anilistId': ?anilistId,
      'kisskhId': ?kisskhId,
      'tmdbId': ?tmdbId,
      'tmdbMediaType': ?tmdbMediaType,
      'imdbId': ?imdbId,
      'kissKhType': ?kissKhType,
      'addedAt': idx >= 0
          ? _items[idx]['addedAt']
          : DateTime.now().millisecondsSinceEpoch,
    };
    if (idx >= 0) _items.removeAt(idx);
    _items.insert(0, row);
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
    final uid = movieId(tmdbId, mediaType);
    final idx = _items.indexWhere((e) => e['uniqueId'] == uid);
    final row = <String, dynamic>{
      if (idx >= 0) ..._items[idx],
      'uniqueId': uid,
      'tmdbId': tmdbId,
      'imdbId': imdbId,
      'title': title,
      'posterPath': posterPath,
      'mediaType': mediaType,
      'voteAverage': voteAverage,
      'releaseDate': releaseDate,
      'source': 'tmdb',
      'listStatus': listStatus,
      'addedAt': idx >= 0
          ? _items[idx]['addedAt']
          : DateTime.now().millisecondsSinceEpoch,
    };
    if (idx >= 0) _items.removeAt(idx);
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
    final uid = movieId(tmdbId, mediaType);
    if (contains(uid)) return;
    _items.insert(0, {
      'uniqueId': uid,
      'tmdbId': tmdbId,
      'imdbId': imdbId,
      'title': title,
      'posterPath': posterPath,
      'mediaType': mediaType,
      'voteAverage': voteAverage,
      'releaseDate': releaseDate,
      'source': 'tmdb',
      'listStatus': defaultStatus,
      'addedAt': DateTime.now().millisecondsSinceEpoch,
    });
    await _save();
    syncAddHandler?.call(tmdbId, imdbId, mediaType);
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

  Future<void> remove(String uniqueId) async {
    await _ensureLoaded();
    final item = _items.cast<Map<String, dynamic>?>().firstWhere(
          (e) => e?['uniqueId'] == uniqueId,
          orElse: () => null,
        );
    final tmdbId = item?['tmdbId'] as int?;
    final imdbId = item?['imdbId']?.toString();
    final mediaType = item?['mediaType']?.toString() ?? 'movie';
    _items.removeWhere((e) => e['uniqueId'] == uniqueId);
    await _save();
    syncRemoveHandler?.call(tmdbId, imdbId, mediaType);
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
    final uid = movieId(tmdbId, mediaType);
    if (contains(uid)) {
      await remove(uid);
      return false;
    }
    await addMovie(
      tmdbId: tmdbId,
      imdbId: imdbId,
      title: title,
      posterPath: posterPath,
      mediaType: mediaType,
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
}
