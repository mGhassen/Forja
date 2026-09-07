import 'package:forja/shared/foundation/services/live/live_stream_engine.dart';
import 'package:forja/shared/foundation/services/live/live_sports_host.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/foundation/protocol/protocol.dart';

/// Feature schedule source ids (opaque to kit).
abstract final class LiveSportsListSources {
  LiveSportsListSources._();

  static const liveSchedule = LiveSportsHost.listSourceId;

  static LiveScheduleSource? resolve(String sourceId) {
    if (sourceId == liveSchedule) return const LiveScheduleListSource();
    return null;
  }
}

/// One live schedule query (catalog + sport + horizon filters).
class LiveScheduleQuery {
  const LiveScheduleQuery({
    this.catalogFilter = 'all',
    this.sportFilter = 'all',
    this.scheduleHorizon = '24h',
  });

  final String catalogFilter;
  final String sportFilter;
  final String scheduleHorizon;
}

/// Host schedule backend — loads enabled Forja Live catalog plugins into meta.
abstract class LiveScheduleSource {
  String get id;

  Future<List<MetaItem>> load(LiveScheduleQuery query);
}

/// Default schedule source (RFC-073) — engine catalog rows → [MetaItem].
class LiveScheduleListSource implements LiveScheduleSource {
  const LiveScheduleListSource();

  @override
  String get id => LiveSportsListSources.liveSchedule;

  @override
  Future<List<MetaItem>> load(LiveScheduleQuery query) async {
    final rows = await loadLiveScheduleRows(query);
    return [for (final row in rows) liveMetaFromScheduleRow(row)];
  }
}

/// Engine catalog rows (opaque maps) for kit list + play bridge.
Future<List<Map<String, dynamic>>> loadLiveScheduleRows(
  LiveScheduleQuery query,
) async {
  await LiveMatchesEngine.warmPluginMeta();
  final plugins = await EngineService.instance.listEnabledLiveFeedPlugins();
  if (plugins.isEmpty) return const [];

  final filter = query.catalogFilter.trim();
  final wanted = filter.isEmpty || filter == 'all'
      ? plugins
      : [
          for (final p in plugins)
            if (EngineService.normalizeLiveSportPluginId(p.id) ==
                    EngineService.normalizeLiveSportPluginId(filter) ||
                p.id == filter)
              p,
        ];
  if (wanted.isEmpty) return const [];

  final out = <Map<String, dynamic>>[];
  final seen = <String>{};
  for (final plugin in wanted) {
    try {
      final batch = await EngineService.instance.runLiveFeed(
        catalogPlugin: plugin,
      );
      for (final row in batch) {
        final map = Map<String, dynamic>.from(row);
        map.putIfAbsent('pluginId', () => plugin.id);
        map.putIfAbsent('livePluginId', () => plugin.id);
        final item = liveMetaFromScheduleRow(map);
        if (item.id.isEmpty || !seen.add(item.id)) continue;
        if (query.sportFilter != 'all' && query.sportFilter.isNotEmpty) {
          final kind = item.genres.isNotEmpty
              ? item.genres.first
              : (item.badge ?? '');
          if (!kind.toLowerCase().contains(query.sportFilter.toLowerCase()) &&
              item.type != query.sportFilter) {
            continue;
          }
        }
        if (!liveScheduleRowInHorizon(map, item, query.scheduleHorizon)) {
          continue;
        }
        out.add(map);
      }
    } catch (_) {
      // Skip failed catalogs — hub UI shows per-plugin errors separately.
    }
  }
  return out;
}

/// Whether a schedule row falls inside the selected horizon window.
bool liveScheduleRowInHorizon(
  Map<String, dynamic> row,
  MetaItem item,
  String horizonRaw,
) {
  final horizon = horizonRaw.trim().toLowerCase();
  if (horizon.isEmpty || horizon == 'all' || horizon == 'day') return true;

  final airing = item.airing == true;
  final alwaysOn = row['always_live'] == true ||
      row['alwaysLive'] == true ||
      (item.badge ?? '').toLowerCase().contains('24/7') ||
      item.genres.any((g) => g.toLowerCase().contains('24/7'));

  if (horizon == 'live') return airing || alwaysOn;
  if (alwaysOn) return true;

  final window = switch (horizon) {
    '1h' => const Duration(hours: 1),
    '3h' => const Duration(hours: 3),
    '6h' => const Duration(hours: 6),
    '12h' => const Duration(hours: 12),
    '24h' => const Duration(hours: 24),
    _ => const Duration(hours: 24),
  };

  final start = liveScheduleStartsAt(row, item);
  if (start == null) return airing;
  final now = DateTime.now();
  if (airing) return true;
  final earliest = now.subtract(const Duration(hours: 3));
  final latest = now.add(window);
  return !start.isBefore(earliest) && !start.isAfter(latest);
}

DateTime? liveScheduleStartsAt(Map<String, dynamic> row, MetaItem item) {
  final raw = item.startsAt ??
      (row['startsAt'] ?? row['starts_at'] ?? row['date'] ?? '').toString();
  if (raw.trim().isEmpty) return null;
  final asNum = num.tryParse(raw);
  if (asNum != null) {
    final ms = asNum > 1e12 ? asNum.toInt() : (asNum * 1000).toInt();
    if (ms > 0) return DateTime.fromMillisecondsSinceEpoch(ms);
  }
  return DateTime.tryParse(raw);
}

/// Map a pack catalog row to catalog meta (stable wire contract — RFC-073).
///
/// Preferred keys: `id`, `title`, `startsAt`, `airing`, `viewers`, `kind` /
/// `genres`, `open`, optional `sportMatchGame` / badges / `sources`.
MetaItem liveMetaFromScheduleRow(Map<String, dynamic> row) {
  final id = (row['id'] ?? '').toString().trim();
  final name = (row['title'] ?? row['name'] ?? '').toString().trim();
  final airing = row['airing'] == true || row['live'] == true;
  final starts = (row['startsAt'] ?? row['starts_at'] ?? row['date'] ?? '')
      .toString()
      .trim();
  final viewersRaw = row['viewers'];
  final viewers =
      viewersRaw is num ? viewersRaw.toInt() : int.tryParse('$viewersRaw');
  final sourcesRaw = row['sources'];
  final sources = <Map<String, dynamic>>[];
  if (sourcesRaw is List) {
    for (final s in sourcesRaw) {
      if (s is Map) sources.add(Map<String, dynamic>.from(s));
    }
  }
  final kind = (row['kind'] ??
          row['category'] ??
          row['category_name'] ??
          row['sport'] ??
          '')
      .toString()
      .trim();
  final genresRaw = row['genres'];
  final genres = <String>[];
  if (genresRaw is List) {
    for (final g in genresRaw) {
      final t = g.toString().trim();
      if (t.isNotEmpty) genres.add(t);
    }
  } else if (kind.isNotEmpty) {
    genres.add(kind);
  }

  MetaOpen? open;
  final openRaw = row['open'];
  if (openRaw is Map) {
    open = MetaOpen.fromJson(Map<String, dynamic>.from(openRaw));
  }
  open ??= id.isEmpty ? null : MetaOpen(surface: 'live', id: id);

  return MetaItem(
    id: id,
    type: 'live_match',
    name: name,
    poster: (row['poster'] ?? row['thumbnail'] ?? '').toString(),
    genres: genres,
    badge: kind.isEmpty ? null : kind,
    airing: airing,
    startsAt: starts.isEmpty ? null : starts,
    viewers: viewers,
    sources: sources,
    open: open,
  );
}
