import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/engine/runtime/meta/plugin_actions.dart';
import 'package:forja/shared/engine/runtime/nav/feed_chrome.dart';
import 'package:forja/shared/engine/runtime/nav/plugin_nav.dart';
import 'package:forja/shared/engine/store/external_list_providers.dart';
import 'package:forja/shared/engine/store/list_providers.dart';
import 'package:forja/shared/engine/unlock/live_plugin_engine.dart';
import 'package:forja/shared/engine/unlock/live_stremio_catalog.dart';
import 'package:forja/shared/host/layout/list/list_event_query.dart';
import 'package:forja/shared/host/layout/list/list_source.dart';
import 'package:forja/shared/host/layout/list/plugin_feed_source.dart';
import 'package:forja/shared/host/layout/live_surface_open.dart';
import 'package:forja/shared/host/layout/top_bar_host_hooks.dart';
import 'package:forja_foundation/widgets/chrome/catalog_filter_sheet.dart';

/// Top-bar scrape chip for [LiveSurfaceOpen.listSourceId] schedule loads.
final liveScheduleFeedBusyProvider =
    StateProvider.family<({bool busy, String? label}), String>(
  (ref, pluginId) => (busy: false, label: null),
);

/// Catalog chip options + prefs + scrape busy for Live Sports top bar.
void registerLiveScheduleChromeHooks() {
  KitTopBarHostHooks.loadCatalogOptions = () async {
    final plugins = await EngineService.instance.listEnabledLiveFeedPlugins();
    final out = <({String id, String label})>[
      for (final p in plugins)
        (
          id: EngineService.normalizeLiveSportPluginId(p.id),
          label: p.name.trim().isEmpty ? p.id : p.name.trim(),
        ),
    ];
    out.addAll(await liveStremioCatalogOptions());
    return out;
  };
  KitTopBarHostHooks.openCatalogSheet = (
    context, {
    required current,
    required options,
  }) =>
      showCatalogFilterSheet(
        context,
        current: current,
        options: options,
      );
  KitTopBarHostHooks.readCatalogPref = (ref, {required tabId}) {
    final key = kitChromeKeyForTab(tabId);
    if (key.isEmpty) return 'all';
    return ref.watch(kitFeedCatalogFilterProvider(key));
  };
  KitTopBarHostHooks.catalogChipLabel = (filter, options) {
    final id = (filter ?? 'all').trim();
    if (id.isEmpty || id == 'all') return 'All';
    for (final o in options) {
      if (o.id == id) return o.label;
    }
    if (isLiveStremioCatalogFilter(id)) {
      return liveStremioCatalogChipFallbackLabel(id);
    }
    return id;
  };
  KitTopBarHostHooks.catalogChipSelected = (filter) {
    final id = (filter ?? 'all').trim();
    return id.isNotEmpty && id != 'all';
  };
  KitTopBarHostHooks.writeCatalogFilter =
      (context, filter, {required tabId}) async {
    final key = kitChromeKeyForTab(tabId);
    if (key.isEmpty) return;
    final container = ProviderScope.containerOf(context);
    container.read(kitFeedCatalogFilterProvider(key).notifier).state = filter;
  };
  KitTopBarHostHooks.readFeedBusy = (ref, {required tabId}) {
    final pluginId = PluginNavRegistry.pluginIdForTabSync(tabId)?.trim() ?? '';
    if (pluginId.isEmpty) return (busy: false, label: null);
    return ref.watch(liveScheduleFeedBusyProvider(pluginId));
  };
}

void clearLiveScheduleChromeHooks() {
  KitTopBarHostHooks.loadCatalogOptions = null;
  KitTopBarHostHooks.openCatalogSheet = null;
  KitTopBarHostHooks.readCatalogPref = null;
  KitTopBarHostHooks.catalogChipLabel = null;
  KitTopBarHostHooks.catalogChipSelected = null;
  KitTopBarHostHooks.writeCatalogFilter = null;
  KitTopBarHostHooks.readFeedBusy = null;
}

/// @Deprecated('Use registerLiveScheduleChromeHooks')
void registerLiveScheduleFeedBusyHook() => registerLiveScheduleChromeHooks();


bool _catalogIdMatches(String pluginId, String want) {
  final id = pluginId.trim();
  if (id.isEmpty) return false;
  var w = want.trim();
  if (w.isEmpty || w == 'all') return true;
  if (w.startsWith('catalog-')) w = w.substring(8);
  final wantNorm = w.startsWith('live-') ? w.substring(5) : w;
  return id == w || id == wantNorm || id == 'live-$wantNorm';
}

Future<List<Map<String, dynamic>>> _parseFeedItems(MetaEnvelope env) async {
  if (!env.ok) return const [];
  final items = env.data?['items'];
  if (items is! List) return const [];
  final out = <Map<String, dynamic>>[];
  for (final e in items) {
    if (e is! Map) continue;
    final row = Map<String, dynamic>.from(e);
    if (row['metaOpen'] == null) {
      final stored = row['open'] ?? row['catalogOpen'];
      if (stored is Map) {
        row['metaOpen'] = Map<String, dynamic>.from(stored);
      }
    }
    out.add(row);
  }
  return out;
}

/// Hub `feed` with pre-fetched catalog [rows] — pack only filters/merges/shapes.
Future<List<Map<String, dynamic>>> _hubReduceFeed({
  required String hubPluginId,
  String? packSourceUrl,
  required List<Map<String, dynamic>> rows,
  required Map<String, dynamic> params,
}) async {
  final env = await MetaRuntime.instance.run(
    pluginId: hubPluginId,
    packSourceUrl: packSourceUrl,
    action: 'feed',
    params: {
      ...params,
      'rows': rows,
    },
    forceRefresh: true,
  );
  return _parseFeedItems(env);
}

/// Hub `feed` without host rows (Stremio chip / legacy aggregate).
Future<List<Map<String, dynamic>>> _hubFeedFull({
  required String hubPluginId,
  String? packSourceUrl,
  required Map<String, dynamic> params,
}) async {
  final env = await MetaRuntime.instance.run(
    pluginId: hubPluginId,
    packSourceUrl: packSourceUrl,
    action: 'feed',
    params: params,
    forceRefresh: true,
  );
  return _parseFeedItems(env);
}

/// Host fan-out of live catalog packs; hub `feed` only reduces/merges/shapes.
Stream<PluginFeedPage> loadLiveScheduleProgressive({
  required String hubPluginId,
  String? packSourceUrl,
  required String status,
  required Map<String, dynamic> feedParams,
  required void Function({required bool busy, String? label}) setBusy,
  bool forceRefresh = false,
}) async* {
  final filter = (feedParams['catalogFilter'] ?? 'all').toString().trim();
  if (filter.startsWith('stremio:')) {
    setBusy(busy: true, label: 'Loading…');
    yield pluginFeedPageFromRows(
      const [],
      status,
      loadingRemote: true,
      loadingProgressLabel: 'Loading…',
    );
    final items = await _hubFeedFull(
      hubPluginId: hubPluginId,
      packSourceUrl: packSourceUrl,
      params: {
        ...feedParams,
        if (forceRefresh) 'force': true,
        if (forceRefresh) 'forceRefresh': true,
      },
    );
    setBusy(busy: false, label: null);
    yield pluginFeedPageFromRows(items, status, loadingRemote: false);
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
    yield pluginFeedPageFromRows(const [], status, loadingRemote: false);
    return;
  }

  final raw = <Map<String, dynamic>>[];
  final seen = <String>{};
  final total = wanted.length;
  List<Map<String, dynamic>> painted = const [];

  for (var i = 0; i < wanted.length; i++) {
    final plugin = wanted[i];
    final label = 'Loading ${plugin.name}… ${i + 1}/$total';
    setBusy(busy: true, label: label);
    yield pluginFeedPageFromRows(
      painted,
      status,
      loadingRemote: true,
      loadingProgressLabel: label,
    );

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

    painted = await _hubReduceFeed(
      hubPluginId: hubPluginId,
      packSourceUrl: packSourceUrl,
      rows: raw,
      params: feedParams,
    );
    final more = i + 1 < total;
    yield pluginFeedPageFromRows(
      painted,
      status,
      loadingRemote: more,
      loadingProgressLabel: more ? label : null,
    );
  }

  setBusy(busy: false, label: null);
  yield pluginFeedPageFromRows(painted, status, loadingRemote: false);
}

/// Progressive schedule for pack `kit.list` source [LiveSurfaceOpen.listSourceId].
final liveScheduleFeedProvider = StreamProvider.autoDispose
    .family<PluginFeedPage, PluginFeedKey>((ref, key) async* {
  final pluginId = key.pluginId;
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

  final forceFlag = ref.read(pluginFeedForceRefreshProvider(pluginId));
  if (forceFlag) {
    ref.read(pluginFeedForceRefreshProvider(pluginId).notifier).state = false;
  }

  final tabId = PluginNavRegistry.tabIdForPluginSync(pluginId);
  final packSourceUrl = tabId == null
      ? null
      : PluginNavRegistry.packSourceUrlForTabSync(tabId);

  final busyNotifier = ref.read(liveScheduleFeedBusyProvider(pluginId).notifier);
  final params = <String, dynamic>{
    'status': key.status,
    'hiddenKeys': hiddenKeys.toList(),
    '_rev': revision,
    'catalogFilter': catalogFilter,
    if (horizonPref.isNotEmpty) 'horizon': horizonPref,
    if (searchQ.isNotEmpty) 'q': searchQ,
    if (forceFlag) 'force': true,
    if (forceFlag) 'forceRefresh': true,
  };

  await for (final page in loadLiveScheduleProgressive(
    hubPluginId: pluginId,
    packSourceUrl: packSourceUrl,
    status: key.status,
    feedParams: params,
    forceRefresh: forceFlag,
    setBusy: ({required bool busy, String? label}) {
      busyNotifier.state = (busy: busy, label: label);
    },
  )) {
    final rows = [
      for (final e in page.entriesForKind(null)) e.legacyRow,
    ];
    final enriched = applyPluginFeedEnrichCacheSync(pluginId, rows);
    final painted = pluginFeedPageFromRows(
      enriched,
      key.status,
      loadingRemote: page.loadingRemote,
      loadingProgressLabel: page.loadingProgressLabel,
    );
    Future.microtask(() {
      try {
        schedulePluginFeedEnrich(ref, pluginId, enriched);
      } catch (_) {}
    });
    yield painted;
  }
});

final liveScheduleFeedCatalogProvider =
    Provider.autoDispose.family<AsyncValue<PluginFeedPage>, PluginFeedKey>(
        (ref, key) {
  ref.watch(pluginFeedEnrichEpochProvider(key.pluginId));
  return ref.watch(liveScheduleFeedProvider(key));
});

/// `kit.list` source `live_schedule` — host progressive catalogs + pack reduce.
final class LiveScheduleFeedSource extends KitListSource {
  const LiveScheduleFeedSource(this.pluginId);

  final String pluginId;

  @override
  String get id => LiveSurfaceOpen.listSourceId;

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
    return _asListPage(ref.watch(liveScheduleFeedCatalogProvider(_key(status))));
  }

  @override
  AsyncValue<KitListPage> readPage(WidgetRef ref, String status) {
    return _asListPage(ref.read(liveScheduleFeedCatalogProvider(_key(status))));
  }

  @override
  void listenPage(
    WidgetRef ref,
    String status,
    void Function(AsyncValue<KitListPage> next) onChange,
  ) {
    ref.listen<AsyncValue<PluginFeedPage>>(
      liveScheduleFeedCatalogProvider(_key(status)),
      (prev, next) {
        onChange(_asListPage(next));
      },
    );
  }

  @override
  void setupSideEffects(WidgetRef ref, String status) {}

  @override
  void invalidateOnRefresh(WidgetRef ref) {
    EngineService.instance.cancelLiveCatalog();
    LivePluginEngine.warmPluginMeta();
    clearPluginFeedEnrichCache(pluginId);
    ref.read(pluginFeedForceRefreshProvider(pluginId).notifier).state = true;
    ref.read(listFeedEpochProvider.notifier).bump();
    ref.invalidate(pluginFeedEnrichEpochProvider(pluginId));
    ref.invalidate(liveScheduleFeedProvider);
    ref.invalidate(liveScheduleFeedCatalogProvider);
    ref.read(liveScheduleFeedBusyProvider(pluginId).notifier).state =
        (busy: false, label: null);
  }

  @override
  Future<void> openEntry(
    BuildContext context,
    KitListEntry entry,
  ) =>
      const PluginFeedSource('').openEntry(context, entry);

  @override
  Future<void> openEntryWithChoice(
    BuildContext context,
    KitListEntry entry,
  ) =>
      const PluginFeedSource('').openEntryWithChoice(context, entry);

  @override
  Widget? buildEntryPin(
    BuildContext context,
    KitListEntry entry,
    String tabStatus,
  ) =>
      const PluginFeedSource('').buildEntryPin(context, entry, tabStatus);
}
