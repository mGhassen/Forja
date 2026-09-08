import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/engine/live/live_plugin_engine.dart';
import 'package:forja/shared/foundation/components/layout/kit_list_source.dart';
import 'package:forja/shared/foundation/services/meta/runtime.dart';
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
  });

  final List<KitListEntry> entries;
  final List<String> kindIds;

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

/// One-shot: next [metaFeedCatalogProvider] run bypasses [MetaCache].
/// Set by Refresh / pull-to-refresh before [ref.invalidate].
final metaFeedForceRefreshProvider = StateProvider<bool>((ref) => false);

/// MetaRuntime `feed` for the live hub plugin — pack owns composition via
/// `ctx.host.liveFeed.load`.
///
/// Soft opens reuse pack cache hints (`maxAge` / `swr` on hub `feed`). Refresh
/// sets [metaFeedForceRefreshProvider] so the next run force-refetches.
final metaFeedCatalogProvider =
    FutureProvider.autoDispose<MetaFeedCatalogPage>((ref) async {
  final filters = ref.watch(kitScheduleFiltersProvider);
  final forceRefresh = ref.read(metaFeedForceRefreshProvider);
  // Yield before clearing — mutating StateProvider during FutureProvider
  // create throws and aborts the feed (skeleton stutter).
  final hubId =
      await PluginNavRegistry.pluginIdForEngineType(KitLiveBoot.engineType);
  if (forceRefresh) {
    ref.read(metaFeedForceRefreshProvider.notifier).state = false;
  }
  if (hubId == null || hubId.isEmpty) {
    return const MetaFeedCatalogPage(entries: [], loadingRemote: false);
  }

  var rawItems = <Map<String, dynamic>>[];
  try {
    final env = await MetaRuntime.instance.run(
      pluginId: hubId,
      action: 'feed',
      params: {
        'catalogFilter': filters.catalogFilter,
        'scheduleStatus': filters.scheduleStatus.name,
        'scheduleHorizon': filters.scheduleHorizon.name,
        'sportFilter': filters.sportFilter,
      },
      forceRefresh: forceRefresh,
    );
    if (env.ok) {
      final items = env.data?['items'];
      if (items is List) {
        for (final e in items) {
          if (e is Map) rawItems.add(Map<String, dynamic>.from(e));
        }
      }
    }
  } catch (e, st) {
    debugPrint('[meta_feed] hub feed: $e\n$st');
  }

  final entries = <KitListEntry>[];
  final kinds = <String>{};
  for (final raw in rawItems) {
    final shaped = Map<String, dynamic>.from(raw);
    if ((shaped['name'] ?? '').toString().trim().isEmpty) {
      shaped['name'] = (shaped['title'] ?? '').toString();
    }
    if ((shaped['type'] ?? '').toString().trim().isEmpty) {
      shaped['type'] = 'live_match';
    }
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
    loadingRemote: false,
  );
});

String _kindForMeta(MetaItem meta) {
  for (final g in meta.genres) {
    final t = g.trim().toLowerCase();
    if (t.isNotEmpty) return t;
  }
  final badge = meta.badge?.trim().toLowerCase() ?? '';
  if (badge.isNotEmpty) return badge;
  return 'live_match';
}

/// Generic kit list backend: MetaRuntime feed for a hub plugin.
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

  @override
  AsyncValue<KitListPage> watchPage(WidgetRef ref, String status) {
    return ref.watch(metaFeedCatalogProvider).when(
          data: AsyncData.new,
          error: AsyncError.new,
          loading: AsyncLoading.new,
        );
  }

  @override
  AsyncValue<KitListPage> readPage(WidgetRef ref, String status) {
    return ref.read(metaFeedCatalogProvider).when(
          data: AsyncData.new,
          error: AsyncError.new,
          loading: AsyncLoading.new,
        );
  }

  @override
  void listenPage(
    WidgetRef ref,
    String status,
    void Function(AsyncValue<KitListPage> next) onChange,
  ) {
    ref.listen<AsyncValue<MetaFeedCatalogPage>>(metaFeedCatalogProvider,
        (prev, next) {
      onChange(
        next.when(
          data: AsyncData.new,
          error: AsyncError.new,
          loading: AsyncLoading.new,
        ),
      );
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
