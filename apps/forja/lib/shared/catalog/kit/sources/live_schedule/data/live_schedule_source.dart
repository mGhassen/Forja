import 'package:forja/shared/catalog/kit/sources/live_schedule/play/live_engine.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/engine/engine.dart';

/// Host-backed schedule for `kit.list { source: live_schedule }`.
abstract final class CatalogKitLiveSources {
  CatalogKitLiveSources._();

  static const liveSchedule = 'live_schedule';

  static LiveScheduleSource? resolve(String sourceId) {
    if (sourceId == liveSchedule) return const HubLiveScheduleSource();
    return null;
  }
}

/// One live schedule query (catalog + sport filters).
class LiveScheduleQuery {
  const LiveScheduleQuery({
    this.catalogFilter = 'all',
    this.sportFilter = 'all',
  });

  final String catalogFilter;
  final String sportFilter;
}

/// Host schedule backend — loads enabled Forja Live catalog plugins into meta.
abstract class LiveScheduleSource {
  String get id;

  Future<List<CatalogMetaItem>> load(LiveScheduleQuery query);
}

/// Default `live_schedule` source (RFC-073) — engine catalog rows → [CatalogMetaItem].
class HubLiveScheduleSource implements LiveScheduleSource {
  const HubLiveScheduleSource();

  @override
  String get id => CatalogKitLiveSources.liveSchedule;

  @override
  Future<List<CatalogMetaItem>> load(LiveScheduleQuery query) async {
    await LiveMatchesEngine.warmPluginMeta();
    final plugins =
        await EngineService.instance.listEnabledLiveCatalogPlugins();
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

    final out = <CatalogMetaItem>[];
    final seen = <String>{};
    for (final plugin in wanted) {
      try {
        final batch = await EngineService.instance.runLiveCatalog(
          catalogPlugin: plugin,
        );
        for (final row in batch) {
          if (row is! Map) continue;
          final map = Map<String, dynamic>.from(row);
          final item = liveMetaFromScheduleRow(map);
          if (item.id.isEmpty || !seen.add(item.id)) continue;
          if (query.sportFilter != 'all' && query.sportFilter.isNotEmpty) {
            final cat = (map['category'] ?? map['category_name'] ?? '')
                .toString()
                .toLowerCase();
            if (!cat.contains(query.sportFilter.toLowerCase()) &&
                item.type != query.sportFilter) {
              continue;
            }
          }
          out.add(item);
        }
      } catch (_) {
        // Skip failed catalogs — hub UI shows per-plugin errors separately.
      }
    }
    return out;
  }
}

/// Map a host schedule row (plugin catalog JSON) to catalog meta.
CatalogMetaItem liveMetaFromScheduleRow(Map<String, dynamic> row) {
  final id = (row['id'] ?? row['eventId'] ?? '').toString();
  final name = (row['title'] ?? row['name'] ?? row['event'] ?? '').toString();
  final airing = row['airing'] == true ||
      row['live'] == true ||
      (row['status'] ?? '').toString().toLowerCase() == 'live';
  final starts = (row['starts_at'] ?? row['startsAt'] ?? row['date'] ?? '')
      .toString();
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
  return CatalogMetaItem(
    id: id,
    type: 'live_match',
    name: name,
    poster: (row['poster'] ?? row['thumbnail'] ?? '').toString(),
    airing: airing,
    startsAt: starts.isEmpty ? null : starts,
    viewers: viewers,
    sources: sources,
    open: CatalogOpen(surface: 'live', id: id),
  );
}
