import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/catalog/protocol.dart';

import 'my_list/my_list_catalog_source.dart';
import 'live_schedule/data/live_schedule_source.dart';

/// One row in a host-backed [`CatalogKitTypes.list`] grid.
class CatalogKitListEntry {
  const CatalogKitListEntry({
    required this.meta,
    required this.legacyRow,
    required this.kind,
    this.pluginId,
    this.listStatus,
  });

  final CatalogMetaItem meta;
  final Map<String, dynamic> legacyRow;
  final String kind;
  final String? pluginId;
  final String? listStatus;
}

/// Page of entries returned by a [CatalogKitListSource].
abstract class CatalogKitListPage {
  int get totalCount;
  bool get loadingRemote;
  List<CatalogKitListEntry> entriesForKind(String? kind);
}

/// Host data backend for `kit.list { source: … }`.
abstract class CatalogKitListSource {
  String get id;

  /// Catalog hub plugin id used to pipe enrich companions (may be null).
  String? get hubPluginId;

  AsyncValue<CatalogKitListPage> watchPage(WidgetRef ref, String status);

  void setupSideEffects(WidgetRef ref, String status);

  void invalidateOnRefresh(WidgetRef ref);

  Future<void> openEntry(BuildContext context, CatalogKitListEntry entry);

  Widget? buildEntryPin(
    BuildContext context,
    CatalogKitListEntry entry,
    String tabStatus,
  );
}

/// Registered `kit.list` source ids.
abstract final class CatalogKitListSources {
  CatalogKitListSources._();

  static const myList = 'my_list';
  static const liveSchedule = CatalogKitLiveSources.liveSchedule;

  /// Full-page host bodies (not poster [CatalogKitListWidget]).
  static bool isFullPageHost(String sourceId) =>
      sourceId.trim() == liveSchedule;

  static CatalogKitListSource? resolve(String sourceId) {
    return switch (sourceId.trim()) {
      myList => MyListCatalogSource.instance,
      // Live Sports uses [LiveSportsKitPage] — not the poster list widget.
      liveSchedule => null,
      _ => null,
    };
  }
}
