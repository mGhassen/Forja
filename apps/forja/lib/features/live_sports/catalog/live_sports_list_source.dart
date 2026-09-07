import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/live_sports/schedule_filters.dart';
import 'package:forja/shared/live/schedule_catalog_source.dart';
import 'package:forja/shared/live/live_stream_engine.dart';
import 'package:forja/shared/live/live_play_kit.dart';
import 'package:forja/features/live_sports/live_sports_host.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_kit_list_source.dart';
import 'package:forja/shared/engine/engine.dart';

/// Selected kit list entry for list+panel chrome.
final liveScheduleSelectedEntryProvider =
    StateProvider<CatalogKitListEntry?>((ref) => null);

class LiveScheduleCatalogPage implements CatalogKitListPage {
  const LiveScheduleCatalogPage({
    required this.entries,
    required this.loadingRemote,
    this.sportIds = const [],
  });

  final List<CatalogKitListEntry> entries;
  final List<String> sportIds;

  @override
  final bool loadingRemote;

  @override
  int get totalCount => entries.length;

  @override
  List<CatalogKitListEntry> entriesForKind(String? kind) {
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
  final rows = await loadLiveScheduleRows(
    LiveScheduleQuery(
      catalogFilter: filters.catalogFilter,
      sportFilter: 'all',
    ),
  );
  final entries = <CatalogKitListEntry>[];
  final sports = <String>{};
  for (final row in rows) {
    final meta = liveMetaFromScheduleRow(row);
    if (meta.id.isEmpty) continue;
    final kind = _sportKindForMeta(meta);
    if (kind.isNotEmpty && kind != 'all' && kind != 'live_match') {
      sports.add(kind);
    }
    entries.add(
      CatalogKitListEntry(
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

String _sportKindForMeta(CatalogMetaItem meta) {
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
/// [wantsHostBody] stays false — [CatalogShell] + [CatalogKitListWidget] own
/// browse; streams panel is [LiveSportsStreamsPanelHost].
final class LiveScheduleCatalogSource extends CatalogKitListSource {
  const LiveScheduleCatalogSource._() : super();

  static const instance = LiveScheduleCatalogSource._();

  @override
  String get id => LiveSportsHost.listSourceId;

  @override
  String? get hubPluginId => LiveSportsHost.hubPluginId;

  @override
  AsyncValue<CatalogKitListPage> watchPage(WidgetRef ref, String status) {
    return ref.watch(liveScheduleCatalogProvider).when(
          data: AsyncData.new,
          error: AsyncError.new,
          loading: AsyncLoading.new,
        );
  }

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
    CatalogKitListEntry entry,
  ) async {
    // Panel selection is owned by [CatalogKitListWidget] when a panel host
    // is registered. Cross-route opens still use [LivePlayKit].
  }

  @override
  Widget? buildEntryPin(
    BuildContext context,
    CatalogKitListEntry entry,
    String tabStatus,
  ) =>
      null;

  /// Open from outside the browse shell (other hubs).
  static void openMetaCrossHub(BuildContext context, CatalogMetaItem item) {
    LivePlayKit.openFromCatalogMeta(context, item);
  }
}
