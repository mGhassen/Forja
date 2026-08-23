import 'dart:async';

import 'package:flutter/foundation.dart';

import 'kv.dart';

class WatchHistoryService {
  static final WatchHistoryService _instance = WatchHistoryService._internal();
  factory WatchHistoryService() => _instance;

  WatchHistoryService._internal() {
    _init();
  }

  static const String _key = 'watch_history';
  static const String _dismissedKey = 'dismissed_history';
  final _controller = StreamController<List<Map<String, dynamic>>>.broadcast();
  List<Map<String, dynamic>> _current = [];
  bool _loaded = false;

  Stream<List<Map<String, dynamic>>> get historyStream => _controller.stream;
  List<Map<String, dynamic>> get current => _current;
  bool get isLoaded => _loaded;

  Future<void> _init() async {
    try {
      _current = await getHistory();
    } finally {
      _loaded = true;
      _controller.add(_current);
    }
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
    String? stremioId,
    String? stremioAddonBaseUrl,
    String? stremioType,
    String? mediaType,
  }) async {
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
        final existingPos = existing['position'];
        final existingDur = existing['duration'];
        final updatedAt = existing['updatedAt'] as int? ?? 0;
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
      await kvSetJsonList(_key, list);

      final dismissed = await kvGetJsonStringList(_dismissedKey);
      if (dismissed.contains(uniqueId)) {
        dismissed.remove(uniqueId);
        await kvSetJsonStringList(_dismissedKey, dismissed);
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
      return await kvGetJsonList(_key);
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
      await kvSetJsonList(_key, list);
      _current = list;
      _controller.add(_current);

      final dismissed = await kvGetJsonStringList(_dismissedKey);
      if (!dismissed.contains(uniqueId)) {
        dismissed.add(uniqueId);
        if (dismissed.length > 100) {
          dismissed.removeRange(0, dismissed.length - 100);
        }
        await kvSetJsonStringList(_dismissedKey, dismissed);
        debugPrint('[WatchHistory] Added $uniqueId to dismissed list');
      }
    } catch (e) {
      debugPrint('[WatchHistory] Error removing item: $e');
    }
  }

  /// Clear all movies/TV continue-watching entries and dismissed suppressions.
  Future<void> clearAll() async {
    try {
      await kvSetJsonList(_key, []);
      await kvSetJsonStringList(_dismissedKey, []);
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
      final dismissed = await kvGetJsonStringList(_dismissedKey);
      return dismissed.contains(uniqueId);
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _controller.close();
  }
}
