import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/engine/live/live_plugin_engine.dart';
import 'package:forja/shared/foundation/services/schedule/kit_schedule_window.dart';

/// Query for [aggregateLiveFeed] — catalog filter + schedule window.
class LiveFeedQuery {
  const LiveFeedQuery({
    this.catalogFilter = 'all',
    this.sportFilter = 'all',
    this.scheduleStatus = KitScheduleStatus.both,
    this.scheduleHorizon = KitScheduleHorizon.h24,
  });

  final String catalogFilter;
  final String sportFilter;
  final KitScheduleStatus scheduleStatus;
  final KitScheduleHorizon scheduleHorizon;

  factory LiveFeedQuery.fromHostParams(Map<String, dynamic>? params) {
    final p = params ?? const {};
    final statusName = (p['scheduleStatus'] ?? '').toString();
    final horizonName = (p['scheduleHorizon'] ?? '').toString();
    final status = KitScheduleStatus.values.where((e) => e.name == statusName);
    final horizon =
        KitScheduleHorizon.values.where((e) => e.name == horizonName);
    return LiveFeedQuery(
      catalogFilter: (p['catalogFilter'] ?? 'all').toString(),
      sportFilter: (p['sportFilter'] ?? 'all').toString(),
      scheduleStatus:
          status.isEmpty ? KitScheduleStatus.both : status.first,
      scheduleHorizon:
          horizon.isEmpty ? KitScheduleHorizon.h24 : horizon.first,
    );
  }
}

/// Aggregate enabled live catalog plugins into opaque schedule row maps.
///
/// Called from `ctx.host.liveFeed.load` (hub feed owns composition) — not from
/// a Dart schedule list god path.
Future<List<Map<String, dynamic>>> aggregateLiveFeed(
  LiveFeedQuery query,
) async {
  await LivePluginEngine.warmPluginMeta();
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
        final item = liveMetaFromFeedRow(map);
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
        if (!liveFeedRowMatches(map, item, query)) continue;
        out.add(map);
      }
    } catch (_) {
      // Skip failed catalogs — hub UI shows per-plugin errors separately.
    }
  }
  return out;
}

/// Whether a schedule row matches the Status × Horizon window.
bool liveFeedRowMatches(
  Map<String, dynamic> row,
  MetaItem item,
  LiveFeedQuery query,
) {
  final airing = item.airing == true;
  final alwaysOn = row['always_live'] == true ||
      row['alwaysLive'] == true ||
      (item.badge ?? '').toLowerCase().contains('24/7') ||
      item.genres.any((g) => g.toLowerCase().contains('24/7'));
  return kitScheduleKickoffMatches(
    start: liveFeedStartsAt(row, item),
    status: query.scheduleStatus,
    horizon: query.scheduleHorizon,
    alwaysOn: alwaysOn,
    liveOrAiring: airing,
  );
}

DateTime? liveFeedStartsAt(Map<String, dynamic> row, MetaItem item) {
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
MetaItem liveMetaFromFeedRow(Map<String, dynamic> row) {
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
