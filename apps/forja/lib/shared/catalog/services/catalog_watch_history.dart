import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _homeWatchHistorySource = 'home_watch_history';

/// Home tab movie/TV rows from [WatchHistoryService] — not hub catalog types.
bool isHomeTabWatchHistoryEntry(Map<String, dynamic> item) {
  final mediaType = item['mediaType'] as String?;
  if (mediaType != null &&
      mediaType.isNotEmpty &&
      mediaType != 'movie' &&
      mediaType != 'tv') {
    return false;
  }
  return watchHistoryInt(item['tmdbId'], -1) >= 0;
}

bool isHomeWatchHistoryCatalogEntry(Map<String, dynamic> entry) =>
    entry['source'] == _homeWatchHistorySource;

String _tmdbCoverUrl(String? path) {
  final raw = (path ?? '').trim();
  if (raw.isEmpty) return '';
  if (raw.startsWith('http')) return raw;
  return TmdbApi.getImageUrl(raw);
}

Map<String, dynamic> catalogEntryFromHomeWatchHistory(Map<String, dynamic> item) {
  final tmdbId = watchHistoryInt(item['tmdbId']);
  final season = item['season'] as int?;
  final episode = item['episode'] as int?;
  final mediaType =
      item['mediaType'] as String? ?? (season != null ? 'tv' : 'movie');
  final uniqueId = item['uniqueId']?.toString() ?? '$tmdbId';
  final poster = _tmdbCoverUrl(item['posterPath']?.toString());
  final backdrop = _tmdbCoverUrl(
    (item['backdropPath']?.toString().trim().isNotEmpty ?? false)
        ? item['backdropPath']?.toString()
        : item['posterPath']?.toString(),
  );
  final title = (item['title'] ?? '').toString();
  final meta = CatalogMetaItem(
    id: 'tmdb:$mediaType:$tmdbId',
    type: mediaType,
    name: title,
    poster: poster,
    background: backdrop.isNotEmpty ? backdrop : poster,
    ids: {'tmdb': tmdbId.toString()},
    open: CatalogOpen(
      surface: 'tmdb',
      id: tmdbId.toString(),
      extras: {'mediaType': mediaType},
    ),
  );
  return {
    'metaId': uniqueId,
    'source': _homeWatchHistorySource,
    'title': title,
    'cover': backdrop.isNotEmpty ? backdrop : poster,
    'poster': poster,
    'episodeNumber': episode ?? 1,
    'positionMs': watchHistoryInt(item['position']),
    'durationMs': watchHistoryInt(item['duration']),
    'updatedAt': watchHistoryInt(item['updatedAt']),
    'homeHistory': item,
    'meta': meta.toJson(),
  };
}

/// Pack-scoped Continue Watching — keyed by [pluginId] only.
class CatalogWatchHistory {
  CatalogWatchHistory._();

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static String _storageKey(String pluginId) => 'catalog_cw_$pluginId';

  static Future<List<Map<String, dynamic>>> getAll(String pluginId) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_storageKey(pluginId)) ?? const [];
    final out = <Map<String, dynamic>>[];
    for (final line in raw) {
      try {
        out.add(jsonDecode(line) as Map<String, dynamic>);
      } catch (_) {}
    }
    return out;
  }

  static Future<void> record({
    required String pluginId,
    required CatalogMetaItem meta,
    required int episodeNumber,
    String? episodeVideoId,
    Map<String, dynamic> extras = const {},
    Duration? position,
    Duration? duration,
  }) async {
    final p = await SharedPreferences.getInstance();
    final list = <String>[
      ...(p.getStringList(_storageKey(pluginId)) ?? const []),
    ];
    list.removeWhere((line) {
      try {
        final m = jsonDecode(line) as Map<String, dynamic>;
        return m['metaId'] == meta.id;
      } catch (_) {
        return true;
      }
    });
    list.insert(
      0,
      jsonEncode({
        'metaId': meta.id,
        'pluginId': pluginId,
        'title': meta.name,
        'cover': meta.background.isNotEmpty ? meta.background : meta.poster,
        'poster': meta.poster,
        'episodeNumber': episodeNumber,
        if (episodeVideoId != null && episodeVideoId.isNotEmpty)
          'episodeVideoId': episodeVideoId,
        if (extras.isNotEmpty) 'extras': extras,
        'positionMs': position?.inMilliseconds ?? 0,
        'durationMs': duration?.inMilliseconds ?? 0,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'meta': meta.toJson(),
      }),
    );
    if (list.length > 50) list.removeRange(50, list.length);
    await p.setStringList(_storageKey(pluginId), list);
    revision.value++;
  }

  static Future<void> remove(String pluginId, String metaId) async {
    final p = await SharedPreferences.getInstance();
    final list = <String>[
      ...(p.getStringList(_storageKey(pluginId)) ?? const []),
    ];
    list.removeWhere((line) {
      try {
        return (jsonDecode(line) as Map<String, dynamic>)['metaId'] == metaId;
      } catch (_) {
        return true;
      }
    });
    await p.setStringList(_storageKey(pluginId), list);
    revision.value++;
  }

  static Future<void> clear(String pluginId) async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_storageKey(pluginId));
    revision.value++;
  }

  static CatalogMetaItem? metaFromEntry(Map<String, dynamic> entry) {
    final raw = entry['meta'];
    if (raw is Map) {
      return CatalogMetaItem.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }
}

int _continueEntryTmdbId(Map<String, dynamic> entry) {
  if (isHomeWatchHistoryCatalogEntry(entry)) {
    final home = entry['homeHistory'];
    if (home is Map) return watchHistoryInt(home['tmdbId'], -1);
  }
  final meta = CatalogWatchHistory.metaFromEntry(entry);
  if (meta != null) {
    final fromIds = int.tryParse(meta.ids['tmdb']?.toString() ?? '');
    if (fromIds != null && fromIds >= 0) return fromIds;
    final parts = meta.id.split(':');
    if (parts.length >= 3) return int.tryParse(parts.last) ?? -1;
  }
  return -1;
}

int _continueEntryUpdatedAt(Map<String, dynamic> entry) =>
    watchHistoryInt(entry['updatedAt']);

List<Map<String, dynamic>> _mergeContinueEntriesByShow(
  List<Map<String, dynamic>> entries,
) {
  final byShow = <int, Map<String, dynamic>>{};
  for (final entry in entries) {
    final tmdbId = _continueEntryTmdbId(entry);
    if (tmdbId < 0) continue;
    final existing = byShow[tmdbId];
    if (existing == null ||
        _continueEntryUpdatedAt(entry) > _continueEntryUpdatedAt(existing)) {
      byShow[tmdbId] = entry;
    }
  }
  final out = byShow.values.toList()
    ..sort(
      (a, b) => _continueEntryUpdatedAt(b) - _continueEntryUpdatedAt(a),
    );
  return out.take(10).toList();
}

Future<List<Map<String, dynamic>>> _catalogPackContinueEntries(
  String pluginId,
) async {
  final out = <Map<String, dynamic>>[];
  for (final entry in await CatalogWatchHistory.getAll(pluginId)) {
    final pos = (entry['positionMs'] as num?)?.toInt() ?? 0;
    final dur = (entry['durationMs'] as num?)?.toInt() ?? 0;
    if (!isContinueWatchingRowEntry(pos, dur)) continue;
    out.add(entry);
  }
  return out;
}

Future<List<Map<String, dynamic>>> _homeTabContinueEntries() async {
  final history = await WatchHistoryService().getHistory();
  final homeRows = history.where(isHomeTabWatchHistoryEntry).toList();
  return inProgressPoolByShow(homeRows)
      .map(catalogEntryFromHomeWatchHistory)
      .toList();
}

/// In-progress rows for layout widget type `continue`.
Future<List<Map<String, dynamic>>> catalogContinueEntries(
  String pluginId, {
  bool mergeHomeWatchHistory = false,
}) async {
  final packEntries = await _catalogPackContinueEntries(pluginId);
  if (!mergeHomeWatchHistory) return packEntries.take(10).toList();
  final homeEntries = await _homeTabContinueEntries();
  return _mergeContinueEntriesByShow([...packEntries, ...homeEntries]);
}

/// Opaque resume rows for pack `because` rails — host does not interpret meta.
Future<List<Map<String, dynamic>>> catalogResumeSeeds(String pluginId) async {
  final entries = await CatalogWatchHistory.getAll(pluginId);
  return [
    for (final e in entries)
      {
        'title': e['title'],
        if (e['meta'] is Map) 'meta': e['meta'],
      },
  ];
}
