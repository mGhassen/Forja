import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'facade.dart';
import 'kv.dart';
import 'local_data_scope.dart';
import 'watch_history_resume.dart';

class WatchHistoryService {
  static final WatchHistoryService _instance = WatchHistoryService._internal();
  factory WatchHistoryService() => _instance;

  WatchHistoryService._internal() {
    LocalDataScope.addListener(_onScopeChanged);
    _init();
  }

  static const String _baseKey = 'watch_history';
  static const String _baseDismissedKey = 'dismissed_history';
  String get _key => LocalDataScope.storageKey(_baseKey);
  String get _dismissedKey => LocalDataScope.storageKey(_baseDismissedKey);
  final _controller = StreamController<List<Map<String, dynamic>>>.broadcast();
  List<Map<String, dynamic>> _current = [];
  bool _loaded = false;
  bool _kvMigrated = false;

  Stream<List<Map<String, dynamic>>> get historyStream => _controller.stream;
  List<Map<String, dynamic>> get current => _current;
  bool get isLoaded => _loaded;

  Future<void> _onScopeChanged() async {
    _kvMigrated = false;
    await _reload();
  }

  Future<void> _ensureKvMigrated() async {
    if (_kvMigrated) return;
    _kvMigrated = true;
    if (!Engine.isReady) return;
    await LocalDataScope.migrateKvStringListIfNeeded(
      base: _baseKey,
      readList: kvGetJsonList,
      writeList: kvSetJsonList,
      clearKey: (k) async => kvSetJsonList(k, []),
    );
    await LocalDataScope.migrateKvStringListPlainIfNeeded(
      base: _baseDismissedKey,
      readList: kvGetJsonStringList,
      writeList: kvSetJsonStringList,
      clearKey: (k) async => kvSetJsonStringList(k, []),
    );
  }

  Future<void> _init() async {
    try {
      await _ensureKvMigrated();
      _current = await getHistory();
    } finally {
      _loaded = true;
    }
    _controller.add(_current);
  }

  Future<void> _reload() async {
    try {
      await _ensureKvMigrated();
      _current = await getHistory();
    } catch (_) {
      _current = [];
    }
    _loaded = true;
    _controller.add(_current);
  }

  Future<void> saveProgress({
    required int tmdbId,
    String? imdbId,
    required String title,
    required String posterPath,
    String? backdropPath,
    required String method,
    required String sourceId,
    required int position,
    required int duration,
    int? season,
    int? episode,
    String? episodeTitle,
    String? magnetLink,
    int? fileIndex,
    String? streamUrl,
    String? streamRowKey,
    String? stremioId,
    String? stremioAddonBaseUrl,
    String? stremioType,
    String? mediaType,
  }) async {
    // duration 0 is not a real save — never replace a good row with a poison
    // handoff (external player / early lifecycle).
    if (duration <= 0) {
      debugPrint(
        '[WatchHistory] Skip save for $title — duration=$duration',
      );
      return;
    }

    final uniqueId = season != null && episode != null
        ? '${tmdbId}_S${season}_E$episode'
        : '$tmdbId';

    final entry = {
      'uniqueId': uniqueId,
      'tmdbId': tmdbId,
      'imdbId': imdbId,
      'title': title,
      'posterPath': posterPath,
      if (backdropPath != null && backdropPath.isNotEmpty)
        'backdropPath': backdropPath,
      'method': method,
      'sourceId': sourceId,
      'position': position,
      'duration': duration,
      'season': season,
      'episode': episode,
      'episodeTitle': episodeTitle,
      'magnetLink': magnetLink,
      'fileIndex': fileIndex,
      'streamUrl': streamUrl,
      if (streamRowKey != null && streamRowKey.isNotEmpty)
        'streamRowKey': streamRowKey,
      'stremioId': stremioId,
      'stremioAddonBaseUrl': stremioAddonBaseUrl,
      'stremioType': stremioType,
      'mediaType': mediaType,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };

    try {
      final list = await getHistory();
      final existingIdx = list.indexWhere((item) => item['uniqueId'] == uniqueId);
      if (existingIdx >= 0) {
        final existing = list[existingIdx];
        final existingPos = watchHistoryInt(existing['position']);
        final existingDur = watchHistoryInt(existing['duration']);
        final updatedAt = watchHistoryInt(existing['updatedAt']);
        final ageMs = DateTime.now().millisecondsSinceEpoch - updatedAt;
        if (existingPos == position &&
            existingDur == duration &&
            ageMs < 30000) {
          return;
        }
      }
      list.removeWhere((item) => item['uniqueId'] == uniqueId);
      list.insert(0, entry);
      if (list.length > 50) {
        list.removeRange(50, list.length);
      }
      await _writeJsonList(_key, list);

      final dismissed = await _readJsonStringList(_dismissedKey);
      if (dismissed.contains(uniqueId)) {
        dismissed.remove(uniqueId);
        await _writeJsonStringList(_dismissedKey, dismissed);
        debugPrint(
          '[WatchHistory] Removed $uniqueId from dismissed list (re-watching)',
        );
      }

      debugPrint(
        '[WatchHistory] Saved progress for $title ($uniqueId) at $position ms',
      );
      _current = list;
      _controller.add(_current);
    } catch (e) {
      debugPrint('[WatchHistory] Error saving progress: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getHistory() async {
    try {
      await _ensureKvMigrated();
      return await _readJsonList(_key, legacyKey: _baseKey);
    } catch (e) {
      debugPrint('[WatchHistory] Error fetching history: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getProgress(
    int tmdbId, {
    int? season,
    int? episode,
  }) async {
    final uniqueId = season != null && episode != null
        ? '${tmdbId}_S${season}_E$episode'
        : '$tmdbId';

    try {
      final history = await getHistory();
      for (final item in history) {
        if (item['uniqueId'] == uniqueId) return item;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> removeItem(String uniqueId) async {
    try {
      final list = await getHistory();
      list.removeWhere((item) => item['uniqueId'] == uniqueId);
      await _writeJsonList(_key, list);
      _current = list;
      _controller.add(_current);

      final dismissed = await _readJsonStringList(_dismissedKey);
      if (!dismissed.contains(uniqueId)) {
        dismissed.add(uniqueId);
        if (dismissed.length > 100) {
          dismissed.removeRange(0, dismissed.length - 100);
        }
        await _writeJsonStringList(_dismissedKey, dismissed);
        debugPrint('[WatchHistory] Added $uniqueId to dismissed list');
      }
    } catch (e) {
      debugPrint('[WatchHistory] Error removing item: $e');
    }
  }

  /// Clear continue-watching for the **active** account/profile/guest only.
  Future<void> clearAll() async {
    try {
      await _writeJsonList(_key, []);
      await _writeJsonStringList(_dismissedKey, []);
      _current = [];
      _controller.add(_current);
      debugPrint('[WatchHistory] Cleared all history');
    } catch (e) {
      debugPrint('[WatchHistory] Error clearing history: $e');
      rethrow;
    }
  }

  Future<bool> isDismissed(String uniqueId) async {
    try {
      final dismissed = await _readJsonStringList(_dismissedKey);
      return dismissed.contains(uniqueId);
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _controller.close();
  }

  // ── Engine KV, or direct JSON-file I/O when libffi failed to load ────────

  Future<List<Map<String, dynamic>>> _readJsonList(
    String key, {
    String? legacyKey,
  }) async {
    if (Engine.isReady) {
      final scoped = await kvGetJsonList(key);
      if (scoped.isNotEmpty || legacyKey == null) return scoped;
      return kvGetJsonList(legacyKey);
    }
    final map = await _readStoreFile();
    final scoped = _mapsFromStore(map, key);
    if (scoped.isNotEmpty || legacyKey == null) return scoped;
    return _mapsFromStore(map, legacyKey);
  }

  Future<void> _writeJsonList(String key, List<Map<String, dynamic>> list) async {
    if (Engine.isReady) {
      await kvSetJsonList(key, list);
      return;
    }
    final map = await _readStoreFile();
    map[key] = list;
    if (key != _baseKey) map.remove(_baseKey);
    await _writeStoreFile(map);
  }

  Future<List<String>> _readJsonStringList(String key) async {
    if (Engine.isReady) return kvGetJsonStringList(key);
    final map = await _readStoreFile();
    return _stringsFromStore(map, key);
  }

  Future<void> _writeJsonStringList(String key, List<String> list) async {
    if (Engine.isReady) {
      await kvSetJsonStringList(key, list);
      return;
    }
    final map = await _readStoreFile();
    map[key] = list;
    if (key != _baseDismissedKey) map.remove(_baseDismissedKey);
    await _writeStoreFile(map);
  }

  Future<String> _storePath() => Engine.storagePathForIdentity(
        accountId: LocalDataScope.accountId,
        profileId: LocalDataScope.profileId,
      );

  Future<Map<String, dynamic>> _readStoreFile() async {
    try {
      final path = await _storePath();
      for (final candidate in [path, '$path.bak']) {
        final file = File(candidate);
        if (!await file.exists()) continue;
        final raw = await file.readAsString();
        if (raw.trim().isEmpty) continue;
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      }
    } catch (e) {
      debugPrint('[WatchHistory] store file read failed: $e');
    }
    return {};
  }

  Future<void> _writeStoreFile(Map<String, dynamic> map) async {
    final path = await _storePath();
    final file = File(path);
    await file.parent.create(recursive: true);
    final tmp = File('$path.tmp');
    await tmp.writeAsString(const JsonEncoder.withIndent('  ').convert(map));
    await tmp.rename(path);
    try {
      await File(path).copy('$path.bak');
    } catch (_) {}
  }

  List<Map<String, dynamic>> _mapsFromStore(Map<String, dynamic> map, String key) {
    final v = map[key];
    if (v is! List) return [];
    return [
      for (final e in v)
        if (e is Map) Map<String, dynamic>.from(e),
    ];
  }

  List<String> _stringsFromStore(Map<String, dynamic> map, String key) {
    final v = map[key];
    if (v is! List) return [];
    return [for (final e in v) '$e'];
  }
}
