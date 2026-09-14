import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/engine/unlock/live_plugin_engine.dart';
import 'package:forja/shared/engine/runtime/meta/plugin_actions.dart';
import 'package:forja/shared/engine/runtime/nav/plugin_nav.dart';
import 'package:forja/shared/engine/store/legacy_list_item.dart';
import 'package:forja/shared/engine/runtime/nav/feed_chrome.dart';
import 'package:forja/shared/host/layout/list/list_source.dart';
import 'package:forja/shared/host/layout/list/list_event_query.dart';
import 'package:forja/shared/host/layout/live_surface_open.dart';
import 'package:forja/shared/engine/store/external_list_providers.dart';
import 'package:forja/shared/engine/store/list_providers.dart';
import 'package:forja/shared/player/details/kit_list_status_button.dart';
import 'package:forja/shared/shell/core/forja_shell_layout.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:rust/rust.dart';

/// Flat-items page from a hub pack `feed` (kinds come from pack-shaped rows).
class PluginFeedPage implements KitListPage {
  const PluginFeedPage({
    required this.byKind,
    required this.loadingRemote,
    this.loadingProgressLabel,
  });

  final Map<String, List<KitListEntry>> byKind;
  @override
  final bool loadingRemote;

  @override
  final String? loadingProgressLabel;

  @override
  int get totalCount =>
      byKind.values.fold<int>(0, (sum, list) => sum + list.length);

  @override
  List<KitListEntry> entriesForKind(String? kind) {
    if (kind == null) {
      return [for (final list in byKind.values) ...list];
    }
    return byKind[kind] ?? const [];
  }
}

PluginFeedPage pluginFeedPageFromRows(
  List<Map<String, dynamic>> rows,
  String status, {
  required bool loadingRemote,
  String? loadingProgressLabel,
}) {
  final byKind = <String, List<KitListEntry>>{};
  for (final raw in rows) {
    final listStatus = raw['listStatus']?.toString() ?? status;
    // Stamp tab status onto Simkl stubs so open/bind keeps Watching ≠ Plan to Watch.
    final row = raw['listStatus'] != null
        ? raw
        : (Map<String, dynamic>.from(raw)..['listStatus'] = listStatus);
    final meta = metaItemFromLegacyListItem(row);
    final kind = (row['kind'] ?? row['type'] ?? 'movie').toString();
    final resolved = kind.isEmpty ? 'movie' : kind;
    final entry = KitListEntry(
      meta: meta,
      legacyRow: row,
      kind: resolved,
      pluginId: row['pluginId']?.toString(),
      listStatus: listStatus,
    );
    (byKind[resolved] ??= []).add(entry);
  }
  return PluginFeedPage(
    byKind: byKind,
    loadingRemote: loadingRemote,
    loadingProgressLabel: loadingProgressLabel,
  );
}

/// Per-plugin enrich overlay for flat `items` feeds (MetaRuntime feed enrich
/// only walks `rails`).
final Map<String, Map<String, Map<String, dynamic>>> _feedEnrichCache = {};
final Map<String, Set<String>> _feedEnrichInflight = {};

void clearPluginFeedEnrichCache([String? pluginId]) {
  if (pluginId == null || pluginId.isEmpty) {
    _feedEnrichCache.clear();
    _feedEnrichInflight.clear();
    return;
  }
  _feedEnrichCache.remove(pluginId);
  _feedEnrichInflight.remove(pluginId);
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

List<Map<String, dynamic>> applyPluginFeedEnrichCacheSync(
  String pluginId,
  List<Map<String, dynamic>> rows,
) {
  final cache = _feedEnrichCache[pluginId];
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
  final cache = _feedEnrichCache.putIfAbsent(pluginId, () => {});
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
    debugPrint('[plugin-feed] enrich failed ($pluginId): $e\n$st');
  }
  return applyPluginFeedEnrichCacheSync(pluginId, out);
}

final pluginFeedForceRefreshProvider =
    StateProvider.family<bool, String>((ref, pluginId) => false);

final pluginFeedEnrichEpochProvider =
    StateProvider.family<int, String>((ref, pluginId) => 0);

void schedulePluginFeedEnrich(
  Ref ref,
  String pluginId,
  List<Map<String, dynamic>> rows,
) {
  final inflight = _feedEnrichInflight.putIfAbsent(pluginId, () => {});
  final cache = _feedEnrichCache.putIfAbsent(pluginId, () => {});
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
  final epoch = ref.read(pluginFeedEnrichEpochProvider(pluginId).notifier);
  unawaited(() async {
    try {
      await _enrichRowsWithCache(pluginId, misses);
      epoch.state++;
    } catch (e, st) {
      debugPrint('[plugin-feed] background enrich failed: $e\n$st');
    } finally {
      for (final row in misses) {
        inflight.remove(_enrichCacheKey(row));
      }
    }
  }());
}

typedef PluginFeedKey = ({String pluginId, String status});

/// MetaRuntime `feed` — opaque chrome prefs passed through; pack owns parse.
final pluginFeedProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, PluginFeedKey>(
        (ref, key) async {
  final pluginId = key.pluginId;
  final status = key.status;
  final revision = ref.watch(bookmarkRevisionProvider);
  ref.watch(listFeedEpochProvider);
  ref.watch(externalListsGateProvider);
  final hiddenKeys = ref.watch(bookmarkHiddenKeysProvider);
  final chromeKey = kitChromeKey(pluginId: pluginId);
  final catalogFilter = chromeKey.isEmpty
      ? 'all'
      : ref.watch(kitFeedCatalogFilterProvider(chromeKey));
  final horizonPref = chromeKey.isEmpty
      ? ''
      : ref.watch(kitFeedHorizonPrefProvider(chromeKey));
  final searchQ = chromeKey.isEmpty
      ? ''
      : ref.watch(kitListEventQueryProvider(chromeKey)).trim();

  // Always bypass EngineCache — bookmarks/Simkl change under us; `_rev` alone
  // still lost to soft tab stale + keep-alive until pull-to-refresh.
  final forceFlag = ref.read(pluginFeedForceRefreshProvider(pluginId));
  if (forceFlag) {
    ref.read(pluginFeedForceRefreshProvider(pluginId).notifier).state = false;
  }
  var rawItems = <Map<String, dynamic>>[];
  final tabId = PluginNavRegistry.tabIdForPluginSync(pluginId);
  final packSourceUrl = tabId == null
      ? null
      : PluginNavRegistry.packSourceUrlForTabSync(tabId);
  try {
    final env = await MetaRuntime.instance.run(
      pluginId: pluginId,
      packSourceUrl: packSourceUrl,
      action: 'feed',
      params: {
        'status': status,
        'hiddenKeys': hiddenKeys.toList(),
        '_rev': revision,
        'catalogFilter': catalogFilter,
        if (horizonPref.isNotEmpty) 'horizon': horizonPref,
        if (searchQ.isNotEmpty) 'q': searchQ,
      },
      forceRefresh: true,
    );
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
    debugPrint('[plugin-feed] $pluginId feed: $e\n$st');
  }
  return rawItems;
});

final pluginFeedCatalogProvider =
    Provider.family<AsyncValue<PluginFeedPage>, PluginFeedKey>((ref, key) {
  ref.watch(pluginFeedEnrichEpochProvider(key.pluginId));
  final feed = ref.watch(pluginFeedProvider(key));
  return feed.when(
    skipLoadingOnReload: true,
    skipLoadingOnRefresh: true,
    data: (rawItems) {
      final enriched = applyPluginFeedEnrichCacheSync(key.pluginId, rawItems);
      final pending = List<Map<String, dynamic>>.from(rawItems);
      Future.microtask(() {
        try {
          schedulePluginFeedEnrich(ref, key.pluginId, pending);
        } catch (_) {}
      });
      return AsyncData(
        pluginFeedPageFromRows(
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

Future<void> _openFeedEntry(
  BuildContext context,
  KitListEntry entry, {
  bool forcePick = false,
}) async {
  if (!context.mounted) return;
  final shellTabId = ShellBus.activeShellTabId ?? '';
  if (shellTabId.isEmpty) return;

  final row = Map<String, dynamic>.from(entry.legacyRow);
  final entryPlugin = entry.pluginId?.trim();
  if (entryPlugin != null &&
      entryPlugin.isNotEmpty &&
      row['pluginId'] == null) {
    row['pluginId'] = entryPlugin;
  }
  final known = entry.listStatus?.trim();
  if (known != null && known.isNotEmpty && row['listStatus'] == null) {
    row['listStatus'] = known;
  }
  if (!context.mounted) return;
  await openLegacyListItem(
    context,
    item: row,
    shellTabId: shellTabId,
    forcePick: forcePick,
  );
}

Widget? _feedEntryPin(
  BuildContext context,
  KitListEntry entry,
  String tabStatus,
) {
  final iconSize = shellScaled(context, 18).clamp(12.0, 18.0);
  final knownStatus = entry.listStatus ?? tabStatus;
  final followTarget = listFollowTargetFromLegacyItemSync(entry.legacyRow);
  if (followTarget != null) {
    return KitListStatusButton.follow(
      followTarget: followTarget,
      excludeFromTvTraversal: true,
      iconSize: iconSize,
      knownStatus: knownStatus,
    );
  }

  final tmdbId =
      entry.meta.numericId('tmdb') ?? legacyListTmdbId(entry.legacyRow);
  if (tmdbId == null) return null;
  final row = entry.legacyRow;
  final mt = row['mediaType']?.toString() ?? 'movie';
  final mediaType = (mt == 'tv' || mt == 'series') ? 'tv' : 'movie';
  return KitListStatusButton.movie(
    movie: Movie(
      id: tmdbId,
      imdbId: row['imdbId']?.toString(),
      title: entry.meta.name,
      posterPath: entry.meta.poster,
      backdropPath: entry.meta.background,
      voteAverage: entry.meta.rating ?? 0,
      releaseDate: entry.meta.releaseInfo,
      mediaType: mediaType,
    ),
    excludeFromTvTraversal: true,
    iconSize: iconSize,
    knownStatus: knownStatus,
  );
}

/// Generic kit.list backend: MetaRuntime feed for the shell hub [pluginId].
final class PluginFeedSource extends KitListSource {
  const PluginFeedSource(this.pluginId);

  final String pluginId;

  @override
  String get id => 'plugin:$pluginId';

  @override
  String? get hubPluginId => pluginId;

  PluginFeedKey _key(String status) => (pluginId: pluginId, status: status);

  @override
  void onLayoutFilters(WidgetRef ref, Map<String, String> filters) {
    final key = kitChromeKey(pluginId: pluginId);
    if (key.isEmpty) return;
    final catalog = filters['catalog'];
    if (catalog != null && catalog.isNotEmpty) {
      final current = ref.read(kitFeedCatalogFilterProvider(key));
      if (catalog != current) {
        ref.read(kitFeedCatalogFilterProvider(key).notifier).state = catalog;
      }
    }
    final horizon = filters['horizon'];
    if (horizon != null && horizon.isNotEmpty) {
      final current = ref.read(kitFeedHorizonPrefProvider(key));
      if (horizon != current) {
        ref.read(kitFeedHorizonPrefProvider(key).notifier).state = horizon;
      }
    }
  }

  @override
  String? takePendingSelectEntryId() =>
      LiveSurfaceOpen.takePendingOpenEntryId();

  static AsyncValue<KitListPage> _asListPage(
    AsyncValue<PluginFeedPage> next,
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
    return _asListPage(ref.watch(pluginFeedCatalogProvider(_key(status))));
  }

  @override
  AsyncValue<KitListPage> readPage(WidgetRef ref, String status) {
    return _asListPage(ref.read(pluginFeedCatalogProvider(_key(status))));
  }

  @override
  void listenPage(
    WidgetRef ref,
    String status,
    void Function(AsyncValue<KitListPage> next) onChange,
  ) {
    ref.listen<AsyncValue<PluginFeedPage>>(
      pluginFeedCatalogProvider(_key(status)),
      (prev, next) {
        onChange(_asListPage(next));
      },
    );
  }

  @override
  void setupSideEffects(WidgetRef ref, String status) {
    ref.listen(pluginFeedCatalogProvider(_key(status)), (prev, next) {
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
    EngineService.instance.cancelLiveCatalog();
    LivePluginEngine.warmPluginMeta();
    clearPluginFeedEnrichCache(pluginId);
    ref.read(pluginFeedForceRefreshProvider(pluginId).notifier).state = true;
    ref.invalidate(bookmarkRevisionProvider);
    ref.read(listFeedEpochProvider.notifier).bump();
    ref.invalidate(simklWatchlistProvider);
    ref.invalidate(pluginFeedEnrichEpochProvider(pluginId));
    ref.invalidate(pluginFeedProvider);
    ref.invalidate(pluginFeedCatalogProvider);
  }

  @override
  Future<void> openEntry(
    BuildContext context,
    KitListEntry entry,
  ) =>
      _openFeedEntry(context, entry);

  @override
  Future<void> openEntryWithChoice(
    BuildContext context,
    KitListEntry entry,
  ) =>
      _openFeedEntry(context, entry, forcePick: true);

  @override
  Widget? buildEntryPin(
    BuildContext context,
    KitListEntry entry,
    String tabStatus,
  ) =>
      _feedEntryPin(context, entry, tabStatus);
}
