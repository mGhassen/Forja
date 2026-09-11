import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/engine/live/live_feed_merge.dart';
import 'package:forja/shared/engine/live/live_merge_matching_gate.dart';
import 'package:forja/shared/engine/live/live_plugin_engine.dart';
import 'package:forja/shared/engine/live/live_stremio_catalog.dart';
import 'package:forja/shared/host/live_sports/match_event.dart';
import 'package:forja/shared/host/live_sports/schedule_sport_filter.dart';
import 'package:forja/shared/host/live_sports/schedule/kit_schedule_window.dart';

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

/// Unfiltered scrape rows keyed by catalog chip (`all` / normalized plugin id /
/// `stremio:…`). Status × Horizon / sport / Catalog chip (All → one pack) are
/// applied client-side — must not re-run every live catalog plugin.
///
/// Lives until [clearLiveFeedSessionCache] (Refresh / pack reload) — no TTL.
final Map<String, ({List<Map<String, dynamic>> rows, DateTime at})>
    _rawFeedByCatalog = {};

String _rawFeedCacheKey(String catalogFilter) {
  final f = catalogFilter.trim();
  if (f.isEmpty || f == 'all') return 'all';
  if (isLiveStremioCatalogFilter(f)) return f;
  return EngineService.normalizeLiveSportPluginId(f);
}

({List<Map<String, dynamic>> rows, DateTime at})? _rawFeedHit(String key) =>
    _rawFeedByCatalog[key];

/// Newest session scrape time for this Catalog chip. Null if never scraped.
DateTime? liveFeedSessionUpdatedAt(String catalogFilter) {
  final key = _rawFeedCacheKey(catalogFilter);
  final direct = _rawFeedByCatalog[key];
  if (direct != null) return direct.at;
  if (key != 'all') return null;
  DateTime? newest;
  for (final e in _rawFeedByCatalog.entries) {
    if (e.key == 'all' || isLiveStremioCatalogFilter(e.key)) continue;
    if (newest == null || e.value.at.isAfter(newest)) newest = e.value.at;
  }
  return newest;
}

/// Top-bar copy next to Refresh — e.g. `Updated 3m ago`.
String? liveFeedSessionUpdatedLabel(String catalogFilter) {
  final at = liveFeedSessionUpdatedAt(catalogFilter);
  if (at == null) return null;
  final d = DateTime.now().difference(at);
  if (d.inSeconds < 45) return 'Updated just now';
  if (d.inMinutes < 60) return 'Updated ${d.inMinutes}m ago';
  if (d.inHours < 24) return 'Updated ${d.inHours}h ago';
  return 'Updated ${d.inDays}d ago';
}

/// Drop session scrape cache (Refresh / pack reload).
void clearLiveFeedSessionCache() {
  _rawFeedByCatalog.clear();
  _rememberedAllCatalogPool = null;
  _rememberedAllCatalogPoolAt = null;
}

/// Re-filter a warm scrape for Status × Horizon / Catalog chip without network.
Future<List<Map<String, dynamic>>?> tryLiveFeedFromSession(
  LiveFeedQuery query,
) async {
  final hit = _rawFeedHit(_rawFeedCacheKey(query.catalogFilter));
  if (hit != null) {
    return filterLiveFeedRowsAsync(hit.rows, query);
  }
  // Catalog=All after browsing chips — compose in memory, no re-scrape.
  final filter = query.catalogFilter.trim();
  if (filter.isNotEmpty && filter != 'all') return null;
  return _tryComposeAllFromWarmPlugins(query);
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
///
/// Always the **unmerged** scrape (per-catalog rows) so soft-match siblings keep
/// their own viewer counts — never the collapsed Catalog=All card.
List<Map<String, dynamic>>? rememberedLiveFeedAllCatalogPool() {
  final at = _rememberedAllCatalogPoolAt;
  final pool = _rememberedAllCatalogPool;
  if (pool != null &&
      at != null &&
      DateTime.now().difference(at) <= _allCatalogPoolTtl) {
    return pool;
  }
  // Session raw for Catalog=All — same unmerged rows, longer TTL.
  return _rawFeedHit(_rawFeedCacheKey('all'))?.rows;
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
/// Scrapes once per catalog pack (All seeds every pack bucket). Catalog chip /
/// Status × Horizon / sport then refilter in memory. [forceRefresh] drops the
/// session scrape for this chip (Refresh clears all via [clearLiveFeedSessionCache]).
///
/// [onPartial] fires after each catalog (and once at the end) so the list can
/// paint before slower sites finish — same progressive UX as pre-kit Live Sports.
Future<List<Map<String, dynamic>>> aggregateLiveFeed(
  LiveFeedQuery query, {
  LiveFeedPartialCallback? onPartial,
  bool forceRefresh = false,
}) async {
  final filter = query.catalogFilter.trim();
  final cacheKey = _rawFeedCacheKey(filter);
  final mergeMatching = await _shouldMergeMatching(query);
  if (forceRefresh) {
    _rawFeedByCatalog.remove(cacheKey);
  } else {
    final hit = _rawFeedHit(cacheKey);
    if (hit != null) {
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

  // Catalog=All with every pack already warm (e.g. browsed each chip) — compose.
  if (!forceRefresh && (filter.isEmpty || filter == 'all')) {
    final composed = _composeAllFromPluginCaches(
      plugins: wanted,
      query: query,
      mergeMatching: mergeMatching,
      onPartial: onPartial,
    );
    if (composed != null) return composed;
  }

  // Seed warm packs immediately; only network-scrape cold ones.
  final raw = <Map<String, dynamic>>[];
  final seen = <String>{};
  final cold = <EnginePlugin>[];
  final scrapeAll = filter.isEmpty || filter == 'all';
  for (final plugin in wanted) {
    final pluginKey = _rawFeedCacheKey(
      EngineService.normalizeLiveSportPluginId(plugin.id),
    );
    final warm = !forceRefresh ? _rawFeedHit(pluginKey) : null;
    if (warm == null) {
      cold.add(plugin);
      continue;
    }
    for (final row in warm.rows) {
      final map = Map<String, dynamic>.from(row);
      final item = liveMetaFromFeedRow(map);
      if (item.id.isEmpty || !seen.add(item.id)) continue;
      raw.add(map);
    }
  }

  final warmCount = wanted.length - cold.length;
  if (raw.isNotEmpty || cold.isEmpty) {
    onPartial?.call(
      LiveFeedPartial(
        rows: _filterLiveFeedRows(
          raw,
          query,
          mergeMatching: mergeMatching,
        ),
        done: cold.isEmpty,
        completed: warmCount,
        total: wanted.length,
        currentLabel: cold.isEmpty
            ? null
            : (cold.first.name.trim().isEmpty
                ? cold.first.id
                : cold.first.name.trim()),
      ),
    );
  }
  if (cold.isEmpty) {
    _rememberRawFeed(cacheKey, raw);
    if (scrapeAll) rememberLiveFeedAllCatalogPool(raw);
    final out = _filterLiveFeedRows(
      raw,
      query,
      mergeMatching: mergeMatching,
    );
    onPartial?.call(
      LiveFeedPartial(
        rows: List<Map<String, dynamic>>.from(out),
        done: true,
        completed: wanted.length,
        total: wanted.length,
      ),
    );
    return out;
  }

  for (var i = 0; i < cold.length; i++) {
    final plugin = cold[i];
    final pluginKey = _rawFeedCacheKey(
      EngineService.normalizeLiveSportPluginId(plugin.id),
    );
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
        completed: warmCount + i,
        total: wanted.length,
        currentLabel: label,
      ),
    );

    List<Map<String, dynamic>> pluginRows = const [];
    try {
      final batch = await EngineService.instance.runLiveFeed(
        catalogPlugin: plugin,
      );
      final collected = <Map<String, dynamic>>[];
      for (final row in batch) {
        final map = Map<String, dynamic>.from(row);
        map.putIfAbsent('pluginId', () => plugin.id);
        map.putIfAbsent('livePluginId', () => plugin.id);
        final item = liveMetaFromFeedRow(map);
        if (item.id.isEmpty) continue;
        collected.add(map);
      }
      pluginRows = collected;
      _rememberRawFeed(pluginKey, pluginRows);
    } catch (_) {
      // Skip failed catalogs — hub UI shows per-plugin errors separately.
    }

    for (final map in pluginRows) {
      final item = liveMetaFromFeedRow(map);
      if (item.id.isEmpty || !seen.add(item.id)) continue;
      raw.add(map);
    }
    onPartial?.call(
      LiveFeedPartial(
        rows: _filterLiveFeedRows(
          raw,
          query,
          mergeMatching: mergeMatching,
        ),
        done: false,
        completed: warmCount + i + 1,
        total: wanted.length,
        currentLabel: label,
      ),
    );
  }
  _rememberRawFeed(cacheKey, raw);
  if (scrapeAll) {
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
      completed: wanted.length,
      total: wanted.length,
    ),
  );
  return out;
}

Future<List<Map<String, dynamic>>?> _tryComposeAllFromWarmPlugins(
  LiveFeedQuery query,
) async {
  await LivePluginEngine.warmPluginMeta();
  final plugins = await EngineService.instance.listEnabledLiveFeedPlugins();
  if (plugins.isEmpty) return null;
  final mergeMatching = await _shouldMergeMatching(query);
  return _composeAllFromPluginCaches(
    plugins: plugins,
    query: query,
    mergeMatching: mergeMatching,
  );
}

/// Build Catalog=All from warm per-plugin buckets (no network).
List<Map<String, dynamic>>? _composeAllFromPluginCaches({
  required List<EnginePlugin> plugins,
  required LiveFeedQuery query,
  required bool mergeMatching,
  LiveFeedPartialCallback? onPartial,
}) {
  final batches = <List<Map<String, dynamic>>>[];
  for (final plugin in plugins) {
    final hit = _rawFeedHit(
      _rawFeedCacheKey(EngineService.normalizeLiveSportPluginId(plugin.id)),
    );
    if (hit == null) return null;
    batches.add(hit.rows);
  }
  final raw = <Map<String, dynamic>>[];
  final seen = <String>{};
  for (final batch in batches) {
    for (final row in batch) {
      final map = Map<String, dynamic>.from(row);
      final item = liveMetaFromFeedRow(map);
      if (item.id.isEmpty || !seen.add(item.id)) continue;
      raw.add(map);
    }
  }
  _rememberRawFeed('all', raw);
  rememberLiveFeedAllCatalogPool(raw);
  final out = _filterLiveFeedRows(raw, query, mergeMatching: mergeMatching);
  onPartial?.call(
    LiveFeedPartial(
      rows: List<Map<String, dynamic>>.from(out),
      done: true,
      completed: plugins.length,
      total: plugins.length,
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
  final filtered = mergeMatching ? mergeLiveFeedMatchingRows(out) : out;
  return sortLiveFeedRowsLiveFirst(filtered);
}

/// Live / airing / always-on first, then viewers desc, then kickoff asc.
List<Map<String, dynamic>> sortLiveFeedRowsLiveFirst(
  List<Map<String, dynamic>> rows,
) {
  if (rows.length < 2) return rows;
  final keyed = [
    for (final row in rows)
      (
        row: row,
        event: MatchEvent.fromLegacyRow(row),
      ),
  ];
  keyed.sort((a, b) {
    final liveA = a.event.isLive;
    final liveB = b.event.isLive;
    if (liveA != liveB) return liveA ? -1 : 1;
    final va = a.event.viewers;
    final vb = b.event.viewers;
    if (va != vb) return vb.compareTo(va);
    final da = a.event.dateMs;
    final db = b.event.dateMs;
    if (da != db) return da.compareTo(db);
    return a.event.id.compareTo(b.event.id);
  });
  return [for (final k in keyed) k.row];
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
  final viewers = parseLiveViewerCount(row['viewers']);
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
