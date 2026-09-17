import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/engine/runtime/kit/pack_opaque_run.dart';
import 'package:forja/shared/engine/unlock/live_stremio_catalog.dart';

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

/// Hub `feed` without host rows (Stremio chip / legacy aggregate).
Future<MetaEnvelope> _hubFeedFull({
  required String hubPluginId,
  String? packSourceUrl,
  required Map<String, dynamic> params,
  required bool forceRefresh,
}) {
  return packOpaqueRun(
    pluginId: hubPluginId,
    packSourceUrl: packSourceUrl,
    action: 'feed',
    params: _feedParamsForReduce(params),
    forceRefresh: forceRefresh,
  );
}

/// Host fans live catalogs one-by-one; hub `feed` only reduces/merges/shapes.
///
/// Yields a [MetaEnvelope] after each catalog so [PackLoadedPaint] can paint
/// before the last scrape finishes (issue 278).
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

  if (isLiveStremioCatalogFilter(filter)) {
    setBusy(busy: true, label: 'Loading…');
    try {
      yield await _hubFeedFull(
        hubPluginId: hubPluginId,
        packSourceUrl: packSourceUrl,
        params: {
          ...feedParams,
          if (forceRefresh) 'force': true,
          if (forceRefresh) 'forceRefresh': true,
        },
        forceRefresh: forceRefresh,
      );
    } finally {
      setBusy(busy: false, label: null);
    }
    return;
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
    final label = 'Loading $name… ${i + 1}/$total';
    setBusy(busy: true, label: label);

    try {
      final batch = await EngineService.instance.runLiveFeed(
        catalogPlugin: plugin,
      );
      for (final row in batch) {
        final map = Map<String, dynamic>.from(row);
        map['pluginId'] ??= plugin.id;
        map['livePluginId'] ??= plugin.id;
        final id = map['id']?.toString().trim() ?? '';
        if (id.isEmpty || !seen.add(id)) continue;
        raw.add(map);
      }
    } catch (e, st) {
      debugPrint('[live-schedule] ${plugin.id} catalog: $e\n$st');
    }

    last = await _hubReduceFeed(
      hubPluginId: hubPluginId,
      packSourceUrl: packSourceUrl,
      rows: raw,
      params: feedParams,
    );
    yield last;
  }

  setBusy(busy: false, label: null);
  if (last != null) yield last;
}
