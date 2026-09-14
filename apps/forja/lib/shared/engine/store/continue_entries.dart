import 'package:forja/shared/engine/store/watch_history.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja_foundation/utils/cover_urls.dart';
import 'package:rust/rust.dart';

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

bool isHomeWatchHistoryEntry(Map<String, dynamic> entry) =>
    entry['source'] == _homeWatchHistorySource;

String _coverUrl(String? path) {
  final raw = (path ?? '').trim();
  if (raw.isEmpty) return '';
  return normalizeCoverUrl(raw);
}

Map<String, dynamic> catalogEntryFromHomeWatchHistory(Map<String, dynamic> item) {
  final tmdbId = watchHistoryInt(item['tmdbId']);
  final season = item['season'] as int?;
  final episode = item['episode'] as int?;
  final mediaType =
      item['mediaType'] as String? ?? (season != null ? 'tv' : 'movie');
  final uniqueId = item['uniqueId']?.toString() ?? '$tmdbId';
  final poster = _coverUrl(item['posterPath']?.toString());
  final backdrop = _coverUrl(
    (item['backdropPath']?.toString().trim().isNotEmpty ?? false)
        ? item['backdropPath']?.toString()
        : item['posterPath']?.toString(),
  );
  final title = (item['title'] ?? '').toString();
  final meta = MetaItem(
    id: 'tmdb:$mediaType:$tmdbId',
    type: mediaType,
    name: title,
    poster: poster,
    background: backdrop.isNotEmpty ? backdrop : poster,
    ids: {'tmdb': tmdbId.toString()},
    open: MetaOpen(
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

/// Pack + identity Continue Watching — keyed by [pluginId] and account/profile/guest.

int _continueEntryTmdbId(Map<String, dynamic> entry) {
  if (isHomeWatchHistoryEntry(entry)) {
    final home = entry['homeHistory'];
    if (home is Map) return watchHistoryInt(home['tmdbId'], -1);
  }
  final meta = WatchHistory.metaFromEntry(entry);
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
  for (final entry in await WatchHistory.getAll(pluginId)) {
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
