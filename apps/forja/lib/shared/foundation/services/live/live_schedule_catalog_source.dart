import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/foundation/services/live/live_play_kit.dart';
import 'package:forja/shared/foundation/services/live/live_sports_host.dart';
import 'package:forja/shared/foundation/services/live/live_stream_engine.dart';
import 'package:forja/shared/foundation/services/live/schedule_filters.dart';
import 'package:forja/shared/foundation/services/live/schedule_list_source.dart';
import 'package:forja/shared/foundation/components/layout/kit_list_source.dart';
import 'package:forja/shared/foundation/protocol/protocol.dart';
import 'package:forja/shared/engine/engine.dart';

/// Selected kit list entry for list+panel chrome.
final liveScheduleSelectedEntryProvider =
    StateProvider<KitListEntry?>((ref) => null);

class LiveScheduleCatalogPage implements KitListPage {
  const LiveScheduleCatalogPage({
    required this.entries,
    required this.loadingRemote,
    this.sportIds = const [],
  });

  final List<KitListEntry> entries;
  final List<String> sportIds;

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

final liveScheduleCatalogProvider =
    FutureProvider.autoDispose<LiveScheduleCatalogPage>((ref) async {
  final filters = ref.watch(liveScheduleFiltersProvider);
  // Sport chips filter client-side — never re-fetch the whole schedule.
  final rows = await loadLiveScheduleRows(
    LiveScheduleQuery(
      catalogFilter: filters.catalogFilter,
      sportFilter: 'all',
      scheduleHorizon: filters.scheduleHorizon,
    ),
  );
  final entries = <KitListEntry>[];
  final sports = <String>{};
  for (final row in rows) {
    final meta = liveMetaFromScheduleRow(row);
    if (meta.id.isEmpty) continue;
    final kind = _sportKindForMeta(meta);
    if (kind.isNotEmpty && kind != 'all' && kind != 'live_match') {
      sports.add(kind);
    }
    entries.add(
      KitListEntry(
        meta: meta,
        legacyRow: row,
        kind: kind.isEmpty ? 'live_match' : kind,
        pluginId: (row['pluginId'] ?? row['livePluginId'] ?? '').toString(),
      ),
    );
  }
  final sportIds = sports.toList()..sort();
  return LiveScheduleCatalogPage(
    entries: entries,
    sportIds: sportIds,
    loadingRemote: false,
  );
});

String _sportKindForMeta(MetaItem meta) {
  for (final g in meta.genres) {
    final t = g.trim().toLowerCase();
    if (t.isNotEmpty) return t;
  }
  final badge = meta.badge?.trim().toLowerCase() ?? '';
  if (badge.isNotEmpty) return badge;
  return 'live_match';
}

/// Kit list backend for `source: live_schedule` (My List peer).
///
/// [wantsHostBody] stays false — [KitShell] + [KitListWidget] own
/// browse; streams panel is [LiveSportsStreamsPanelHost].
final class LiveScheduleCatalogSource extends KitListSource {
  const LiveScheduleCatalogSource._() : super();

  static const instance = LiveScheduleCatalogSource._();

  @override
  String get id => LiveSportsHost.listSourceId;

  @override
  String? get hubPluginId => LiveSportsHost.hubPluginId;

  @override
  AsyncValue<KitListPage> watchPage(WidgetRef ref, String status) {
    return ref.watch(liveScheduleCatalogProvider).when(
          data: AsyncData.new,
          error: AsyncError.new,
          loading: AsyncLoading.new,
        );
  }

  @override
  void onLayoutFilters(WidgetRef ref, Map<String, String> filters) {
    final catalog = filters['catalog'];
    final horizon = filters['horizon'];
    // Sport/kind is client-side via kit.list entriesForKind — do not reload.
    final current = ref.read(liveScheduleFiltersProvider);
    final notifier = ref.read(liveScheduleFiltersProvider.notifier);
    if (catalog != null &&
        catalog.isNotEmpty &&
        catalog != current.catalogFilter) {
      notifier.setCatalogFilter(catalog);
    }
    if (horizon != null &&
        horizon.isNotEmpty &&
        horizon != current.scheduleHorizon) {
      notifier.setScheduleHorizon(horizon);
    }
  }

  @override
  String? takePendingSelectEntryId() => LivePlayKit.takePendingOpenMatchId();

  @override
  void setupSideEffects(WidgetRef ref, String status) {}

  @override
  void invalidateOnRefresh(WidgetRef ref) {
    EngineService.instance.cancelLiveCatalog();
    LiveMatchesEngine.warmPluginMeta();
    ref.invalidate(liveScheduleCatalogProvider);
  }

  @override
  Future<void> openEntry(
    BuildContext context,
    KitListEntry entry,
  ) async {
    // Browse open is kit-owned (panel vs details from pack layout).
  }

  @override
  Widget? buildEntryPin(
    BuildContext context,
    KitListEntry entry,
    String tabStatus,
  ) =>
      null;

  /// Open from outside the browse shell (other hubs).
  static void openMetaCrossHub(BuildContext context, MetaItem item) {
    LivePlayKit.openFromMeta(context, item);
  }
}
