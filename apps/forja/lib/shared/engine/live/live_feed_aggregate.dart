import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/engine/live/live_feed_merge.dart';
import 'package:forja/shared/engine/live/live_merge_matching_gate.dart';
import 'package:forja/shared/engine/live/live_plugin_engine.dart';
import 'package:forja/shared/engine/live/live_stremio_catalog.dart';
import 'package:forja/shared/foundation/services/schedule/kit_schedule_window.dart';

/// Query for [aggregateLiveFeed] — catalog filter + schedule window.
class LiveFeedQuery {
  const LiveFeedQuery({
    this.catalogFilter = 'all',
    this.sportFilter = 'all',
    this.scheduleStatus = KitScheduleStatus.airing,
    this.scheduleHorizon = KitScheduleHorizon.h1,
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
          status.isEmpty ? KitScheduleStatus.airing : status.first,
      scheduleHorizon:
          horizon.isEmpty ? KitScheduleHorizon.h1 : horizon.first,
    );
  }
}

/// Last full-catalog schedule rows (Catalog = All) for Providers soft-match.
List<Map<String, dynamic>>? _rememberedAllCatalogPool;
DateTime? _rememberedAllCatalogPoolAt;
const _allCatalogPoolTtl = Duration(minutes: 3);

/// Unfiltered scrape rows keyed by catalog chip (`all` / plugin id / stremio:…).
/// Status × Horizon (and sport) are applied client-side — schedule chip must
/// not re-run every live catalog plugin.
final Map<String, ({List<Map<String, dynamic>> rows, DateTime at})>
    _rawFeedByCatalog = {};
const _rawFeedTtl = Duration(minutes: 5);

String _rawFeedCacheKey(String catalogFilter) {
  final f = catalogFilter.trim();
  return f.isEmpty ? 'all' : f;
}

/// Drop session scrape cache (Refresh / pack reload).
void clearLiveFeedSessionCache() {
  _rawFeedByCatalog.clear();
  _rememberedAllCatalogPool = null;
  _rememberedAllCatalogPoolAt = null;
}

/// Re-filter a warm scrape for a new Status × Horizon without network.
Future<List<Map<String, dynamic>>?> tryLiveFeedFromSession(
  LiveFeedQuery query,
) async {
  final hit = _rawFeedByCatalog[_rawFeedCacheKey(query.catalogFilter)];
  if (hit == null) return null;
  if (DateTime.now().difference(hit.at) > _rawFeedTtl) return null;
  return filterLiveFeedRowsAsync(hit.rows, query);
}

/// Status × Horizon (+ optional same-fixture merge for Catalog = All).
Future<List<Map<String, dynamic>>> filterLiveFeedRowsAsync(
  List<Map<String, dynamic>> rows,
  LiveFeedQuery query,
) async {
  final mergeMatching = await _shouldMergeMatching(query);
  return _filterLiveFeedRows(rows, query, mergeMatching: mergeMatching);
}

Future<bool> _shouldMergeMatching(LiveFeedQuery query) async {
  final filter = query.catalogFilter.trim();
  if (filter.isNotEmpty && filter != 'all') return false;
  return LiveMergeMatchingGate.isEnabled();
}

void _rememberRawFeed(String catalogFilter, List<Map<String, dynamic>> rows) {
  _rawFeedByCatalog[_rawFeedCacheKey(catalogFilter)] = (
    rows: [for (final r in rows) Map<String, dynamic>.from(r)],
    at: DateTime.now(),
  );
}

/// Warm/read the unscoped schedule pool used when resolving Providers.
List<Map<String, dynamic>>? rememberedLiveFeedAllCatalogPool() {
  final at = _rememberedAllCatalogPoolAt;
  final pool = _rememberedAllCatalogPool;
  if (pool == null || at == null) return null;
  if (DateTime.now().difference(at) > _allCatalogPoolTtl) return null;
  return pool;
}

void rememberLiveFeedAllCatalogPool(List<Map<String, dynamic>> rows) {
  _rememberedAllCatalogPool = [
    for (final r in rows) Map<String, dynamic>.from(r),
  ];
  _rememberedAllCatalogPoolAt = DateTime.now();
}

/// Partial schedule paint while [aggregateLiveFeed] scrapes catalogs.
class LiveFeedPartial {
  const LiveFeedPartial({
    required this.rows,
    required this.done,
    required this.completed,
    required this.total,
    this.currentLabel,
  });

  final List<Map<String, dynamic>> rows;
  final bool done;
  final int completed;
  final int total;
  final String? currentLabel;

  /// Top-bar / empty-state copy — e.g. `Loading ESPN… 2/10`.
  String get progressLabel {
    final progress = '$completed/$total';
    final name = (currentLabel ?? '').trim();
    if (name.isEmpty) return 'Loading catalogs… $progress';
    return 'Loading $name… $progress';
  }
}

typedef LiveFeedPartialCallback = void Function(LiveFeedPartial partial);

/// Aggregate enabled live catalog plugins into opaque schedule row maps.
///
/// Called from `ctx.host.liveFeed.load` (hub feed owns composition) — not from
/// a Dart schedule list god path.
///
/// Scrapes once per catalog chip, then applies Status × Horizon / sport in
/// memory. [forceRefresh] drops the session scrape cache (Refresh).
///
/// [onPartial] fires after each catalog (and once at the end) so the list can
/// paint before slower sites finish — same progressive UX as pre-kit Live Sports.
Future<List<Map<String, dynamic>>> aggregateLiveFeed(
  LiveFeedQuery query, {
  LiveFeedPartialCallback? onPartial,
  bool forceRefresh = false,
}) async {
  final filter = query.catalogFilter.trim();
  final mergeMatching = await _shouldMergeMatching(query);
  if (forceRefresh) {
    _rawFeedByCatalog.remove(_rawFeedCacheKey(filter));
  } else {
    final hit = _rawFeedByCatalog[_rawFeedCacheKey(filter)];
    if (hit != null &&
        DateTime.now().difference(hit.at) <= _rawFeedTtl) {
      final session = _filterLiveFeedRows(
        hit.rows,
        query,
        mergeMatching: mergeMatching,
      );
      onPartial?.call(
        LiveFeedPartial(
          rows: session,
          done: true,
          completed: 1,
          total: 1,
        ),
      );
      return session;
    }
  }

  // Stremio live addon chip — one addon schedule (RFC-050), not merged into All.
  if (isLiveStremioCatalogFilter(filter)) {
    final base = liveStremioBaseUrlFromCatalogFilter(filter);
    if (base == null) {
      onPartial?.call(
        const LiveFeedPartial(
          rows: [],
          done: true,
          completed: 0,
          total: 0,
        ),
      );
      return const [];
    }
    onPartial?.call(
      const LiveFeedPartial(
        rows: [],
        done: false,
        completed: 0,
        total: 1,
        currentLabel: 'Stremio',
      ),
    );
    final raw = await loadLiveStremioCatalogFeed(baseUrl: base);
    _rememberRawFeed(filter, raw);
    final filtered =
        _filterLiveFeedRows(raw, query, mergeMatching: false);
    onPartial?.call(
      LiveFeedPartial(
        rows: filtered,
        done: true,
        completed: 1,
        total: 1,
        currentLabel: 'Stremio',
      ),
    );
    return filtered;
  }

  await LivePluginEngine.warmPluginMeta();
  final plugins = await EngineService.instance.listEnabledLiveFeedPlugins();
  if (plugins.isEmpty) {
    onPartial?.call(
      const LiveFeedPartial(
        rows: [],
        done: true,
        completed: 0,
        total: 0,
      ),
    );
    return const [];
  }

  final wanted = filter.isEmpty || filter == 'all'
      ? plugins
      : [
          for (final p in plugins)
            if (EngineService.normalizeLiveSportPluginId(p.id) ==
                    EngineService.normalizeLiveSportPluginId(filter) ||
                p.id == filter)
              p,
        ];
  if (wanted.isEmpty) {
    onPartial?.call(
      const LiveFeedPartial(
        rows: [],
        done: true,
        completed: 0,
        total: 0,
      ),
    );
    return const [];
  }

  final raw = <Map<String, dynamic>>[];
  final seen = <String>{};
  final total = wanted.length;
  for (var i = 0; i < wanted.length; i++) {
    final plugin = wanted[i];
    final label =
        plugin.name.trim().isEmpty ? plugin.id : plugin.name.trim();
    onPartial?.call(
      LiveFeedPartial(
        rows: _filterLiveFeedRows(
          raw,
          query,
          mergeMatching: mergeMatching,
        ),
        done: false,
        completed: i,
        total: total,
        currentLabel: label,
      ),
    );
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
        raw.add(map);
      }
    } catch (_) {
      // Skip failed catalogs — hub UI shows per-plugin errors separately.
    }
    onPartial?.call(
      LiveFeedPartial(
        rows: _filterLiveFeedRows(
          raw,
          query,
          mergeMatching: mergeMatching,
        ),
        done: false,
        completed: i + 1,
        total: total,
        currentLabel: label,
      ),
    );
  }
  _rememberRawFeed(filter, raw);
  if (filter.isEmpty || filter == 'all') {
    // Unmerged pool — Providers soft-matches siblings from every catalog.
    rememberLiveFeedAllCatalogPool(raw);
  }
  final out = _filterLiveFeedRows(
    raw,
    query,
    mergeMatching: mergeMatching,
  );
  onPartial?.call(
    LiveFeedPartial(
      rows: List<Map<String, dynamic>>.from(out),
      done: true,
      completed: total,
      total: total,
    ),
  );
  return out;
}

List<Map<String, dynamic>> _filterLiveFeedRows(
  List<Map<String, dynamic>> rows,
  LiveFeedQuery query, {
  required bool mergeMatching,
}) {
  final out = <Map<String, dynamic>>[];
  final seen = <String>{};
  for (final row in rows) {
    final map = Map<String, dynamic>.from(row);
    final item = liveMetaFromFeedRow(map);
    if (item.id.isEmpty || !seen.add(item.id)) continue;
    if (!_rowPassesSportAndWindow(map, item, query)) continue;
    out.add(map);
  }
  if (!mergeMatching) return out;
  return mergeLiveFeedMatchingRows(out);
}

bool _rowPassesSportAndWindow(
  Map<String, dynamic> map,
  MetaItem item,
  LiveFeedQuery query,
) {
  if (query.sportFilter != 'all' && query.sportFilter.isNotEmpty) {
    final kind =
        item.genres.isNotEmpty ? item.genres.first : (item.badge ?? '');
    if (!kind.toLowerCase().contains(query.sportFilter.toLowerCase()) &&
        item.type != query.sportFilter) {
      return false;
    }
  }
  return liveFeedRowMatches(map, item, query);
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
      if (s is! Map) continue;
      final m = Map<String, dynamic>.from(s);
      final source = (m['source'] ?? '').toString().trim();
      final id = (m['id'] ?? '').toString().trim();
      if (source.isEmpty || id.isEmpty) continue;
      // Opaque resolve keys only — drop catalog iframe/url embeds.
      sources.add({'source': source, 'id': id});
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
