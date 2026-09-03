import 'package:forja/shared/catalog/kit/sources/live_schedule/data/live_mode_registry.dart';
import 'package:forja/shared/catalog/protocol.dart';

/// Host-backed schedule for `kit.list { source: live_schedule }`.
abstract final class CatalogKitLiveSources {
  CatalogKitLiveSources._();

  static const liveSchedule = 'live_schedule';

  static LiveScheduleSource? resolve(String sourceId) {
    if (sourceId == liveSchedule) return const HubLiveScheduleSource();
    return null;
  }
}

/// One live schedule query (mode + catalog + sport).
class LiveScheduleQuery {
  const LiveScheduleQuery({
    required this.mode,
    this.catalogFilter = 'all',
    this.sportFilter = 'all',
  });

  final LiveModeId mode;
  final String catalogFilter;
  final String sportFilter;
}

/// Host schedule backend. Browse merge still runs inside [LiveSportsHubPage];
/// [load] maps opaque schedule rows to [CatalogMetaItem] for kit consumers.
abstract class LiveScheduleSource {
  String get id;

  Future<List<CatalogMetaItem>> load(LiveScheduleQuery query);
}

/// Default `live_schedule` source — identity mapper for host-owned rows.
class HubLiveScheduleSource implements LiveScheduleSource {
  const HubLiveScheduleSource();

  @override
  String get id => CatalogKitLiveSources.liveSchedule;

  @override
  Future<List<CatalogMetaItem>> load(LiveScheduleQuery query) async {
    return const [];
  }
}

/// Map a host schedule row (plugin catalog JSON) to catalog meta.
CatalogMetaItem liveMetaFromScheduleRow(
  Map<String, dynamic> row, {
  String mode = 'forja_live',
}) {
  final id = (row['id'] ?? row['eventId'] ?? '').toString();
  final name = (row['title'] ?? row['name'] ?? row['event'] ?? '').toString();
  final airing = row['airing'] == true ||
      row['live'] == true ||
      (row['status'] ?? '').toString().toLowerCase() == 'live';
  final starts = (row['starts_at'] ?? row['startsAt'] ?? row['date'] ?? '')
      .toString();
  final viewersRaw = row['viewers'];
  final viewers = viewersRaw is num ? viewersRaw.toInt() : int.tryParse('$viewersRaw');
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
    mode: mode,
    sources: sources,
    open: CatalogOpen(surface: 'live', id: id),
  );
}
