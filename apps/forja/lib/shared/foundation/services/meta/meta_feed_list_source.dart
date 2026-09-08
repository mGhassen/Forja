import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/engine/live/live_feed_aggregate.dart';
import 'package:forja/shared/engine/live/live_plugin_engine.dart';
import 'package:forja/shared/foundation/components/layout/kit_list_source.dart';
import 'package:forja/shared/foundation/services/meta/cache.dart';
import 'package:forja/shared/foundation/services/nav/plugin_nav.dart';
import 'package:forja/shared/foundation/services/play/live_surface_open.dart';
import 'package:forja/shared/foundation/services/schedule/kit_live_boot.dart';
import 'package:forja/shared/foundation/services/schedule/kit_schedule_filters.dart';

/// Selected kit list entry for list+panel chrome.
final metaFeedSelectedEntryProvider =
    StateProvider<KitListEntry?>((ref) => null);

class MetaFeedCatalogPage implements KitListPage {
  const MetaFeedCatalogPage({
    required this.entries,
    required this.loadingRemote,
    this.kindIds = const [],
    this.loadingProgressLabel,
  });

  final List<KitListEntry> entries;
  final List<String> kindIds;

  /// Top-bar chip while catalogs scrape — e.g. `Loading ESPN… 2/10`.
  @override
  final String? loadingProgressLabel;

  @override
  final bool loadingRemote;

  @override
  int get totalCount => entries.length;

  @override
  List<KitListEntry> entriesForKind(String? kind) {
    if (kind == null || kind.isEmpty || kind == 'all') return entries;
    final want = kind.toLowerCase();
    return [
      for (final e in entries)
        if (e.kind == want || e.kind.contains(want)) e,
    ];
  }
}

/// One-shot: next [metaFeedCatalogProvider] run bypasses soft MetaCache.
/// Set by Refresh / pull-to-refresh before [ref.invalidate].
final metaFeedForceRefreshProvider = StateProvider<bool>((ref) => false);

/// Progressive live hub schedule — paints as each catalog finishes.
final metaFeedCatalogProvider = AsyncNotifierProvider.autoDispose<
    MetaFeedCatalogNotifier, MetaFeedCatalogPage>(MetaFeedCatalogNotifier.new);

class MetaFeedCatalogNotifier
    extends AutoDisposeAsyncNotifier<MetaFeedCatalogPage> {
  int _gen = 0;

  @override
  Future<MetaFeedCatalogPage> build() async {
    // Survive PlayerSurfaceChromeStub unmount while a live match plays — otherwise
    // autoDispose drops the feed and Back from the player re-scrapes every catalog.
    ref.keepAlive();

    final filters = ref.watch(kitScheduleFiltersProvider);
    final forceRefresh = ref.read(metaFeedForceRefreshProvider);
    final gen = ++_gen;

    // Yield before clearing — mutating StateProvider during create throws.
    final hubId =
        await PluginNavRegistry.pluginIdForEngineType(KitLiveBoot.engineType);
    if (forceRefresh) {
      ref.read(metaFeedForceRefreshProvider.notifier).state = false;
    }
    if (hubId == null || hubId.isEmpty) {
      return const MetaFeedCatalogPage(entries: [], loadingRemote: false);
    }

    final feedParams = <String, dynamic>{
      'catalogFilter': filters.catalogFilter,
      'scheduleStatus': filters.scheduleStatus.name,
      'scheduleHorizon': filters.scheduleHorizon.name,
      'sportFilter': filters.sportFilter,
    };
    final cacheKey = MetaCache.keyFor(
      pluginId: hubId,
      action: 'feed',
      params: feedParams,
    );

    if (!forceRefresh) {
      final cached = MetaCache.instance.get(cacheKey);
      if (cached != null && cached.isFresh) {
        final page = _pageFromCacheData(cached.data, loadingRemote: false);
        // Soft reopen — still revalidate in background when past maxAge window
        // is not needed while fresh.
        return page;
      }
      if (cached != null && cached.isRevalidatable) {
        // Show stale rows immediately, scrape in background.
        final stale = _pageFromCacheData(cached.data, loadingRemote: true);
        state = AsyncData(stale);
        // Fall through to progressive scrape below.
      } else {
        state = const AsyncData(
          MetaFeedCatalogPage(
            entries: [],
            loadingRemote: true,
            loadingProgressLabel: 'Loading live catalogs…',
          ),
        );
      }
    } else {
      state = const AsyncData(
        MetaFeedCatalogPage(
          entries: [],
          loadingRemote: true,
          loadingProgressLabel: 'Loading live catalogs…',
        ),
      );
    }

    final query = LiveFeedQuery(
      catalogFilter: filters.catalogFilter,
      sportFilter: filters.sportFilter,
      scheduleStatus: filters.scheduleStatus,
      scheduleHorizon: filters.scheduleHorizon,
    );

    List<Map<String, dynamic>> rows = const [];
    try {
      rows = await aggregateLiveFeed(
        query,
        onPartial: (partial) {
          if (gen != _gen) return;
          final page = _pageFromRows(
            partial.rows,
            loadingRemote: !partial.done,
            loadingProgressLabel:
                partial.done ? null : partial.progressLabel,
          );
          state = AsyncData(page);
        },
      );
    } catch (e, st) {
      debugPrint('[meta_feed] hub feed: $e\n$st');
      if (gen != _gen) {
        return const MetaFeedCatalogPage(entries: [], loadingRemote: false);
      }
    }

    if (gen != _gen) {
      return state.value ??
          const MetaFeedCatalogPage(entries: [], loadingRemote: false);
    }

    final page = _pageFromRows(rows, loadingRemote: false);
    MetaCache.instance.put(
      key: cacheKey,
      pluginId: hubId,
      data: {
        'items': [
          for (final e in page.entries) e.legacyRow,
        ],
      },
      hints: const MetaCacheHints(
        maxAge: Duration(seconds: 60),
        swr: Duration(seconds: 300),
      ),
    );
    return page;
  }
}

MetaFeedCatalogPage _pageFromCacheData(
  Map<String, dynamic> data, {
  required bool loadingRemote,
  String? loadingProgressLabel,
}) {
  final items = data['items'];
  final rawItems = <Map<String, dynamic>>[];
  if (items is List) {
    for (final e in items) {
      if (e is Map) rawItems.add(Map<String, dynamic>.from(e));
    }
  }
  return _pageFromRows(
    rawItems,
    loadingRemote: loadingRemote,
    loadingProgressLabel: loadingProgressLabel,
  );
}

MetaFeedCatalogPage _pageFromRows(
  List<Map<String, dynamic>> rawItems, {
  required bool loadingRemote,
  String? loadingProgressLabel,
}) {
  final entries = <KitListEntry>[];
  final kinds = <String>{};
  for (final raw in rawItems) {
    final shaped = _shapeLiveFeedRow(raw);
    final meta = MetaItem.fromJson(shaped);
    if (meta.id.isEmpty) continue;
    final kind = _kindForMeta(meta);
    if (kind.isNotEmpty && kind != 'all' && kind != 'live_match') {
      kinds.add(kind);
    }
    entries.add(
      KitListEntry(
        meta: meta,
        legacyRow: shaped,
        kind: kind.isEmpty ? 'live_match' : kind,
        pluginId:
            (shaped['pluginId'] ?? shaped['livePluginId'] ?? '').toString(),
      ),
    );
  }
  final kindIds = kinds.toList()..sort();
  return MetaFeedCatalogPage(
    entries: entries,
    kindIds: kindIds,
    loadingRemote: loadingRemote,
    loadingProgressLabel: loadingProgressLabel,
  );
}

/// Pack-equivalent row shape (`liveSportsShapeRow`) for host progressive path.
Map<String, dynamic> _shapeLiveFeedRow(Map<String, dynamic> row) {
  final out = Map<String, dynamic>.from(row);
  if ((out['name'] ?? '').toString().trim().isEmpty) {
    out['name'] = (out['title'] ?? '').toString();
  }
  if ((out['type'] ?? '').toString().trim().isEmpty) {
    out['type'] = 'live_match';
  }
  final id = (out['id'] ?? '').toString();
  if (out['open'] == null && id.isNotEmpty) {
    out['open'] = {'surface': 'live', 'id': id};
  }
  if (out['sportMatchGame'] is! Map) {
    final title = (out['title'] ?? out['name'] ?? '').toString();
    final home = (out['homeTeam'] ?? '').toString();
    final away = (out['awayTeam'] ?? '').toString();
    final category = (out['category'] ?? out['sport'] ?? '').toString();
    final dateMs = num.tryParse('${out['dateMs'] ?? 0}')?.toInt() ?? 0;
    out['sportMatchGame'] = {
      'id': id,
      'title': title,
      'homeTeam': home,
      'awayTeam': away,
      'sport': category,
      'category': category,
      'dateMs': dateMs,
    };
  }
  return out;
}

String _kindForMeta(MetaItem meta) {
  for (final g in meta.genres) {
    final t = g.trim().toLowerCase();
    if (t.isNotEmpty) return t;
  }
  final badge = meta.badge?.trim().toLowerCase() ?? '';
  if (badge.isNotEmpty) return badge;
  return 'live_match';
}

/// Generic kit list backend: progressive live schedule for hub packs.
///
/// Opaque [id] (e.g. `live_schedule`) is pack-declared; host never special-
/// cases Live Sports beyond resolving the live hub via [engineType].
final class MetaFeedListSource extends KitListSource {
  const MetaFeedListSource._({
    required this.id,
    required this.engineType,
  });

  /// Opaque `live_schedule` source used by live hub packs.
  static const liveSchedule = MetaFeedListSource._(
    id: KitLiveBoot.listSourceId,
    engineType: KitLiveBoot.engineType,
  );

  @override
  final String id;

  final String engineType;

  @override
  String? get hubPluginId => null;

  /// Remap without stripping previous data on reload — bare
  /// `AsyncLoading.new` made KitListWidget / KitCategoryBar think the
  /// feed was empty (skeleton flash + category bar collapse).
  static AsyncValue<KitListPage> _asListPage(
    AsyncValue<MetaFeedCatalogPage> next,
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
    return _asListPage(ref.watch(metaFeedCatalogProvider));
  }

  @override
  AsyncValue<KitListPage> readPage(WidgetRef ref, String status) {
    return _asListPage(ref.read(metaFeedCatalogProvider));
  }

  @override
  void listenPage(
    WidgetRef ref,
    String status,
    void Function(AsyncValue<KitListPage> next) onChange,
  ) {
    ref.listen<AsyncValue<MetaFeedCatalogPage>>(metaFeedCatalogProvider,
        (prev, next) {
      onChange(_asListPage(next));
    });
  }

  @override
  void onLayoutFilters(WidgetRef ref, Map<String, String> filters) {
    final catalog = filters['catalog'];
    final current = ref.read(kitScheduleFiltersProvider);
    final notifier = ref.read(kitScheduleFiltersProvider.notifier);
    if (catalog != null &&
        catalog.isNotEmpty &&
        catalog != current.catalogFilter) {
      notifier.setCatalogFilter(catalog);
    }
    // Schedule Status×Horizon is owned by [kitScheduleFiltersProvider] (sheet /
    // hydrate). Do not push layout `horizon` back into the provider — that raced
    // the sheet and reset picks to the pack default `both|24h`.
  }

  @override
  String? takePendingSelectEntryId() =>
      LiveSurfaceOpen.takePendingOpenMatchId();

  @override
  void setupSideEffects(WidgetRef ref, String status) {}

  @override
  void invalidateOnRefresh(WidgetRef ref) {
    EngineService.instance.cancelLiveCatalog();
    LivePluginEngine.warmPluginMeta();
    ref.read(metaFeedForceRefreshProvider.notifier).state = true;
    ref.invalidate(metaFeedCatalogProvider);
  }

  @override
  Future<void> openEntry(
    BuildContext context,
    KitListEntry entry,
  ) async {}

  @override
  Widget? buildEntryPin(
    BuildContext context,
    KitListEntry entry,
    String tabStatus,
  ) =>
      null;
}
