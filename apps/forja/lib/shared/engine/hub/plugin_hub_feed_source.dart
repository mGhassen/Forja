import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/hub/catalog_list_open.dart';
import 'package:forja/shared/engine/hub/kit_list_source.dart';
import 'package:forja/shared/engine/hub/legacy_list_item.dart';
import 'package:forja/shared/engine/hub/meta_runtime.dart';
import 'package:forja/shared/engine/lists/external_list_providers.dart';
import 'package:forja/shared/engine/lists/list_providers.dart';

/// Flat-items page from a hub pack `feed` (kinds come from pack-shaped rows).
class PluginHubFeedPage implements KitListPage {
  const PluginHubFeedPage({
    required this.byKind,
    required this.loadingRemote,
  });

  final Map<String, List<KitListEntry>> byKind;
  @override
  final bool loadingRemote;

  @override
  int get totalCount =>
      byKind.values.fold<int>(0, (sum, list) => sum + list.length);

  @override
  String? get loadingProgressLabel => null;

  @override
  List<KitListEntry> entriesForKind(String? kind) {
    if (kind == null) {
      return [for (final list in byKind.values) ...list];
    }
    return byKind[kind] ?? const [];
  }
}

@visibleForTesting
PluginHubFeedPage pluginHubFeedPageFromRows(
  List<Map<String, dynamic>> rows,
  String status, {
  required bool loadingRemote,
}) {
  final byKind = <String, List<KitListEntry>>{};
  for (final row in rows) {
    final meta = metaItemFromLegacyListItem(row);
    final kind = (row['kind'] ?? row['type'] ?? 'movie').toString();
    final resolved = kind.isEmpty ? 'movie' : kind;
    final entry = KitListEntry(
      meta: meta,
      legacyRow: row,
      kind: resolved,
      pluginId: row['pluginId']?.toString(),
      listStatus: row['listStatus']?.toString() ?? status,
    );
    (byKind[resolved] ??= []).add(entry);
  }
  return PluginHubFeedPage(byKind: byKind, loadingRemote: loadingRemote);
}

/// Per-plugin enrich overlay for flat `items` feeds (MetaRuntime feed enrich
/// only walks `rails`).
final Map<String, Map<String, Map<String, dynamic>>> _hubFeedEnrichCache = {};
final Map<String, Set<String>> _hubFeedEnrichInflight = {};

void clearPluginHubFeedEnrichCache([String? pluginId]) {
  if (pluginId == null || pluginId.isEmpty) {
    _hubFeedEnrichCache.clear();
    _hubFeedEnrichInflight.clear();
    return;
  }
  _hubFeedEnrichCache.remove(pluginId);
  _hubFeedEnrichInflight.remove(pluginId);
}

String _enrichCacheKey(Map<String, dynamic> row) {
  final uid = row['uniqueId']?.toString().trim() ?? '';
  if (uid.isNotEmpty) return uid;
  final keys = bookmarkItemHideKeys(row);
  if (keys.isNotEmpty) return (keys.toList()..sort()).join('|');
  final title = row['title']?.toString() ?? '';
  final mt = row['mediaType']?.toString() ?? '';
  return 'title:$mt:$title';
}

bool _rowStillNeedsEnrich(Map<String, dynamic> row) {
  final tmdb = row['tmdbId'];
  final tmdbId = tmdb is int ? tmdb : int.tryParse('$tmdb');
  if (tmdbId == null || tmdbId <= 0) return false;
  final poster = row['posterPath']?.toString().trim() ?? '';
  if (poster.isEmpty) return true;
  final title = row['title']?.toString().trim() ?? '';
  if (title.isEmpty) return true;
  final vote = row['voteAverage'];
  if (vote == null) return true;
  if (vote is num && vote == 0) return true;
  return false;
}

bool _enrichFieldUsable(dynamic v) {
  if (v == null) return false;
  if (v is String) return v.trim().isNotEmpty;
  if (v is num) return v != 0;
  return true;
}

Map<String, dynamic> _overlayEnrich(
  Map<String, dynamic> cached,
  Map<String, dynamic> current,
) {
  final out = Map<String, dynamic>.from(cached);
  for (final key in const [
    'listStatus',
    'uniqueId',
    'tmdbId',
    'pluginId',
    'metaOpen',
    'catalogOpen',
    'open',
    'kind',
    'type',
    'mediaType',
    '_simklType',
  ]) {
    final v = current[key];
    if (v != null) out[key] = v;
  }
  for (final key in const [
    'posterPath',
    'backdropPath',
    'title',
    'name',
    'overview',
    'voteAverage',
    'releaseDate',
  ]) {
    final v = current[key];
    if (_enrichFieldUsable(v)) out[key] = v;
  }
  return out;
}

List<Map<String, dynamic>> _applyEnrichCacheSync(
  String pluginId,
  List<Map<String, dynamic>> rows,
) {
  final cache = _hubFeedEnrichCache[pluginId];
  if (cache == null || cache.isEmpty) return rows;
  return [
    for (final row in rows)
      if (cache[_enrichCacheKey(row)] case final cached?)
        _overlayEnrich(cached, row)
      else
        row,
  ];
}

Future<List<Map<String, dynamic>>> _enrichRowsWithCache(
  String pluginId,
  List<Map<String, dynamic>> rows,
) async {
  if (rows.isEmpty) return rows;
  final cache = _hubFeedEnrichCache.putIfAbsent(pluginId, () => {});
  final out = List<Map<String, dynamic>>.from(rows);
  final misses = <Map<String, dynamic>>[];
  for (var i = 0; i < out.length; i++) {
    final row = out[i];
    final key = _enrichCacheKey(row);
    final cached = cache[key];
    if (cached != null) {
      out[i] = _overlayEnrich(cached, row);
      continue;
    }
    if (!_rowStillNeedsEnrich(row)) {
      cache[key] = Map<String, dynamic>.from(row);
      continue;
    }
    misses.add(row);
  }
  if (misses.isEmpty) return out;
  try {
    final enriched = await MetaRuntime.instance.enrichLegacyListItems(
      sourcePluginId: pluginId,
      items: misses,
    );
    for (final row in enriched) {
      final key = _enrichCacheKey(row);
      cache[key] = row;
    }
  } catch (e, st) {
    debugPrint('[hub-feed] enrich failed ($pluginId): $e\n$st');
  }
  return _applyEnrichCacheSync(pluginId, out);
}

final hubFeedForceRefreshProvider =
    StateProvider.family<bool, String>((ref, pluginId) => false);

final hubFeedEnrichEpochProvider =
    StateProvider.family<int, String>((ref, pluginId) => 0);

void scheduleHubFeedEnrich(
  Ref ref,
  String pluginId,
  List<Map<String, dynamic>> rows,
) {
  final inflight = _hubFeedEnrichInflight.putIfAbsent(pluginId, () => {});
  final cache = _hubFeedEnrichCache.putIfAbsent(pluginId, () => {});
  final misses = <Map<String, dynamic>>[];
  for (final row in rows) {
    final key = _enrichCacheKey(row);
    if (cache.containsKey(key)) continue;
    if (!_rowStillNeedsEnrich(row)) {
      cache[key] = Map<String, dynamic>.from(row);
      continue;
    }
    if (!inflight.add(key)) continue;
    misses.add(row);
  }
  if (misses.isEmpty) return;
  // Capture notifier while [ref] is still valid — do not ref.read after await
  // (autoDispose feed rebuild → !_didChangeDependency).
  final epoch = ref.read(hubFeedEnrichEpochProvider(pluginId).notifier);
  unawaited(() async {
    try {
      await _enrichRowsWithCache(pluginId, misses);
      epoch.state++;
    } catch (e, st) {
      debugPrint('[hub-feed] background enrich failed: $e\n$st');
    } finally {
      for (final row in misses) {
        inflight.remove(_enrichCacheKey(row));
      }
    }
  }());
}

typedef _HubFeedKey = ({String pluginId, String status});

/// MetaRuntime `feed` for any list-typed hub — pack owns composition via
/// `ctx.host.bookmarks` + `ctx.host.simkl`.
final hubPluginFeedProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, _HubFeedKey>((
  ref,
  key,
) async {
  final pluginId = key.pluginId;
  final status = key.status;
  final revision = ref.watch(bookmarkRevisionProvider);
  ref.watch(externalListsGateProvider);
  final hiddenKeys = ref.watch(bookmarkHiddenKeysProvider);

  var forceRefresh = ref.read(hubFeedForceRefreshProvider(pluginId));
  var rawItems = <Map<String, dynamic>>[];
  try {
    final env = await MetaRuntime.instance.run(
      pluginId: pluginId,
      action: 'feed',
      params: {
        'status': status,
        'hiddenKeys': hiddenKeys.toList(),
        '_rev': revision,
      },
      forceRefresh: forceRefresh,
    );
    if (forceRefresh) {
      ref.read(hubFeedForceRefreshProvider(pluginId).notifier).state = false;
    }
    if (env.ok) {
      final items = env.data?['items'];
      if (items is List) {
        for (final e in items) {
          if (e is Map) {
            final row = Map<String, dynamic>.from(e);
            if (row['metaOpen'] == null) {
              final stored = row['open'] ?? row['catalogOpen'];
              if (stored is Map) {
                row['metaOpen'] = Map<String, dynamic>.from(stored);
              }
            }
            rawItems.add(row);
          }
        }
      }
    }
  } catch (e, st) {
    debugPrint('[hub-feed] $pluginId feed: $e\n$st');
    if (forceRefresh) {
      ref.read(hubFeedForceRefreshProvider(pluginId).notifier).state = false;
    }
  }
  return rawItems;
});

final hubPluginCatalogProvider =
    Provider.family<AsyncValue<PluginHubFeedPage>, _HubFeedKey>((ref, key) {
  ref.watch(hubFeedEnrichEpochProvider(key.pluginId));
  final feed = ref.watch(hubPluginFeedProvider(key));
  return feed.when(
    skipLoadingOnReload: true,
    skipLoadingOnRefresh: true,
    data: (rawItems) {
      final enriched = _applyEnrichCacheSync(key.pluginId, rawItems);
      final pending = List<Map<String, dynamic>>.from(rawItems);
      Future.microtask(() {
        try {
          scheduleHubFeedEnrich(ref, key.pluginId, pending);
        } catch (_) {}
      });
      return AsyncData(
        pluginHubFeedPageFromRows(
          enriched,
          key.status,
          loadingRemote: false,
        ),
      );
    },
    error: (e, st) => AsyncError(e, st),
    loading: () => const AsyncLoading(),
  );
});

/// Generic kit.list backend: MetaRuntime feed for the shell hub [pluginId].
final class PluginHubFeedListSource extends KitListSource {
  const PluginHubFeedListSource(this.pluginId);

  final String pluginId;

  @override
  String get id => 'plugin:$pluginId';

  @override
  String? get hubPluginId => pluginId;

  _HubFeedKey _key(String status) => (pluginId: pluginId, status: status);

  static AsyncValue<KitListPage> _asListPage(
    AsyncValue<PluginHubFeedPage> next,
  ) {
    return next.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      data: (page) => AsyncData<KitListPage>(page),
      error: (e, st) => AsyncError<KitListPage>(e, st),
      loading: () => const AsyncLoading<KitListPage>(),
    );
  }

  @override
  AsyncValue<KitListPage> watchPage(WidgetRef ref, String status) {
    return _asListPage(ref.watch(hubPluginCatalogProvider(_key(status))));
  }

  @override
  AsyncValue<KitListPage> readPage(WidgetRef ref, String status) {
    return _asListPage(ref.read(hubPluginCatalogProvider(_key(status))));
  }

  @override
  void listenPage(
    WidgetRef ref,
    String status,
    void Function(AsyncValue<KitListPage> next) onChange,
  ) {
    ref.listen<AsyncValue<PluginHubFeedPage>>(
      hubPluginCatalogProvider(_key(status)),
      (prev, next) {
        onChange(_asListPage(next));
      },
    );
  }

  @override
  void setupSideEffects(WidgetRef ref, String status) {
    ref.listen(hubPluginCatalogProvider(_key(status)), (prev, next) {
      if (!next.hasValue) return;
      final gate = ref.read(externalListsGateProvider).valueOrNull;
      if (gate?.simklLoggedIn != true) return;
      final cards = [
        for (final entry in next.requireValue.entriesForKind(null))
          entry.legacyRow,
      ];
      ref.read(bookmarkHiddenKeysProvider.notifier).retainOnlyPresentIn(cards);
    });
  }

  @override
  void invalidateOnRefresh(WidgetRef ref) {
    clearPluginHubFeedEnrichCache(pluginId);
    ref.read(hubFeedForceRefreshProvider(pluginId).notifier).state = true;
    ref.invalidate(bookmarkRevisionProvider);
    ref.invalidate(simklWatchlistProvider);
    ref.invalidate(hubFeedEnrichEpochProvider(pluginId));
    ref.invalidate(hubPluginFeedProvider);
    ref.invalidate(hubPluginCatalogProvider);
  }

  @override
  Future<void> openEntry(
    BuildContext context,
    KitListEntry entry,
  ) =>
      openCatalogListEntry(context, entry);

  @override
  Widget? buildEntryPin(
    BuildContext context,
    KitListEntry entry,
    String tabStatus,
  ) =>
      catalogListEntryPin(context, entry, tabStatus);
}
