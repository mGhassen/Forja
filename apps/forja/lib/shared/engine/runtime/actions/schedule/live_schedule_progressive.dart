import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/engine/runtime/kit/pack_opaque_run.dart';
import 'package:forja/shared/engine/unlock/live_stremio_catalog.dart';

/// Same namespace/keys as pack `hubs/live_sports/_feed.js` (`LIVE_FEED_CACHE_NS`).
const _kLiveFeedCacheNs = 'live_sports.feed';
const _kLiveFeedCacheTtl = Duration(minutes: 15);

/// Top-bar scrape chip for live schedule progressive loads.
final liveScheduleFeedBusyProvider =
    StateProvider.family<({bool busy, String? label}), String>(
  (ref, pluginId) => (busy: false, label: null),
);

bool _catalogIdMatches(String pluginId, String want) {
  final id = pluginId.trim();
  if (id.isEmpty) return false;
  var w = want.trim();
  if (w.isEmpty || w == 'all') return true;
  if (w.startsWith('catalog-')) w = w.substring(8);
  final wantNorm = w.startsWith('live-') ? w.substring(5) : w;
  return id == w || id == wantNorm || id == 'live-$wantNorm';
}

/// Pack `liveFeedCacheKey` — catalog filter only (schedule/sport filter in reduce).
String _liveFeedCacheKey(String catalogFilter) {
  var f = catalogFilter.trim();
  if (f.isEmpty || f == 'all') return 'raw:all';
  if (f.startsWith('stremio:')) return 'raw:$f';
  if (f.startsWith('live-')) f = f.substring(5);
  if (f.startsWith('catalog-')) f = f.substring(8);
  return 'raw:$f';
}

List<Map<String, dynamic>>? _cachedFeedRows(String cacheKey) {
  final hit = EngineCache.instance.get(_kLiveFeedCacheNs, cacheKey);
  if (hit is! Map) return null;
  final rows = hit['rows'];
  if (rows is! List || rows.isEmpty) return null;
  final out = <Map<String, dynamic>>[];
  for (final row in rows) {
    if (row is Map) out.add(Map<String, dynamic>.from(row));
  }
  return out.isEmpty ? null : out;
}

void _storeFeedRows(String cacheKey, List<Map<String, dynamic>> rows) {
  EngineCache.instance.set(
    _kLiveFeedCacheNs,
    cacheKey,
    {
      'rows': rows,
      'at': DateTime.now().millisecondsSinceEpoch,
    },
    ttl: _kLiveFeedCacheTtl,
  );
}

Map<String, dynamic> _feedParamsForReduce(Map<String, dynamic> params) {
  final out = Map<String, dynamic>.from(params);
  out.remove('progressiveCatalogs');
  return out;
}

/// Hub `feed` with pre-fetched catalog [rows] — pack only filters/merges/shapes.
Future<MetaEnvelope> _hubReduceFeed({
  required String hubPluginId,
  String? packSourceUrl,
  required List<Map<String, dynamic>> rows,
  required Map<String, dynamic> params,
}) {
  return packOpaqueRun(
    pluginId: hubPluginId,
    packSourceUrl: packSourceUrl,
    action: 'feed',
    params: {
      ..._feedParamsForReduce(params),
      'rows': rows,
    },
    forceRefresh: true,
  );
}

/// Host fans live catalogs one-by-one; hub `feed` only reduces/merges/shapes.
///
/// Yields a [MetaEnvelope] after each catalog so [PackLoadedPaint] can paint
/// before the last scrape finishes (issue 278).
///
/// Raw rows share pack `live_sports.feed` (catalog-filter keys only). Schedule /
/// sport / horizon changes re-reduce from cache — same as pre-progressive release.
Stream<MetaEnvelope> loadLiveScheduleProgressive({
  required String hubPluginId,
  String? packSourceUrl,
  required Map<String, dynamic> feedParams,
  required void Function({required bool busy, String? label}) setBusy,
  bool forceRefresh = false,
}) async* {
  final filter = (feedParams['catalogFilter'] ?? feedParams['section'] ?? 'all')
      .toString()
      .trim();

  if (forceRefresh) {
    EngineCache.instance.invalidate(_kLiveFeedCacheNs);
  }

  if (isLiveStremioCatalogFilter(filter)) {
    setBusy(busy: true, label: 'Loading…');
    try {
      final cacheKey = _liveFeedCacheKey(filter);
      if (!forceRefresh) {
        final warm = _cachedFeedRows(cacheKey);
        if (warm != null) {
          setBusy(busy: false, label: null);
          yield await _hubReduceFeed(
            hubPluginId: hubPluginId,
            packSourceUrl: packSourceUrl,
            rows: warm,
            params: feedParams,
          );
          return;
        }
      }
      final base = liveStremioBaseUrlFromCatalogFilter(filter);
      final rows = base == null
          ? const <Map<String, dynamic>>[]
          : await loadLiveStremioCatalogFeed(baseUrl: base);
      if (rows.isNotEmpty) _storeFeedRows(cacheKey, rows);
      yield await _hubReduceFeed(
        hubPluginId: hubPluginId,
        packSourceUrl: packSourceUrl,
        rows: rows,
        params: feedParams,
      );
    } finally {
      setBusy(busy: false, label: null);
    }
    return;
  }

  final aggregateKey = _liveFeedCacheKey(filter);
  if (!forceRefresh) {
    final warm = _cachedFeedRows(aggregateKey);
    if (warm != null) {
      setBusy(busy: false, label: null);
      yield await _hubReduceFeed(
        hubPluginId: hubPluginId,
        packSourceUrl: packSourceUrl,
        rows: warm,
        params: feedParams,
      );
      return;
    }
  }

  List<EnginePlugin> wanted;
  try {
    final all = await EngineService.instance.listEnabledLiveFeedPlugins();
    if (filter.isEmpty || filter == 'all') {
      wanted = all;
    } else {
      wanted = [
        for (final p in all)
          if (_catalogIdMatches(p.id, filter)) p,
      ];
    }
  } catch (e, st) {
    debugPrint('[live-schedule] list catalogs: $e\n$st');
    wanted = const [];
  }

  if (wanted.isEmpty) {
    setBusy(busy: false, label: null);
    yield await _hubReduceFeed(
      hubPluginId: hubPluginId,
      packSourceUrl: packSourceUrl,
      rows: const [],
      params: feedParams,
    );
    return;
  }

  final raw = <Map<String, dynamic>>[];
  final seen = <String>{};
  final total = wanted.length;
  MetaEnvelope? last;

  for (var i = 0; i < wanted.length; i++) {
    final plugin = wanted[i];
    final name = plugin.name.trim().isEmpty ? plugin.id : plugin.name.trim();
    final pluginKey = _liveFeedCacheKey(plugin.id);

    List<Map<String, dynamic>>? batch;
    if (!forceRefresh) {
      batch = _cachedFeedRows(pluginKey);
    }

    if (batch != null) {
      setBusy(busy: false, label: null);
      for (final row in batch) {
        final map = Map<String, dynamic>.from(row);
        map['pluginId'] ??= plugin.id;
        map['livePluginId'] ??= plugin.id;
        final id = map['id']?.toString().trim() ?? '';
        if (id.isEmpty || !seen.add(id)) continue;
        raw.add(map);
      }
    } else {
      setBusy(busy: true, label: 'Loading $name… ${i + 1}/$total');
      try {
        final scraped = await EngineService.instance.runLiveFeed(
          catalogPlugin: plugin,
        );
        final collected = <Map<String, dynamic>>[];
        for (final row in scraped) {
          final map = Map<String, dynamic>.from(row);
          map['pluginId'] ??= plugin.id;
          map['livePluginId'] ??= plugin.id;
          collected.add(map);
          final id = map['id']?.toString().trim() ?? '';
          if (id.isEmpty || !seen.add(id)) continue;
          raw.add(map);
        }
        if (collected.isNotEmpty) {
          _storeFeedRows(pluginKey, collected);
        }
      } catch (e, st) {
        debugPrint('[live-schedule] ${plugin.id} catalog: $e\n$st');
      }
    }

    last = await _hubReduceFeed(
      hubPluginId: hubPluginId,
      packSourceUrl: packSourceUrl,
      rows: raw,
      params: feedParams,
    );
    yield last;
  }

  if (raw.isNotEmpty) {
    _storeFeedRows(aggregateKey, raw);
  }

  setBusy(busy: false, label: null);
  if (last != null) yield last;
}
