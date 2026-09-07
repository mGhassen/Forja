import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/foundation/protocol/protocol.dart';

/// One row in a host-backed [`KitTypes.list`] grid.
class KitListEntry {
  const KitListEntry({
    required this.meta,
    required this.legacyRow,
    required this.kind,
    this.pluginId,
    this.listStatus,
  });

  final MetaItem meta;
  final Map<String, dynamic> legacyRow;
  final String kind;
  final String? pluginId;
  final String? listStatus;
}

/// Page of entries returned by a [KitListSource].
abstract class KitListPage {
  int get totalCount;
  bool get loadingRemote;
  List<KitListEntry> entriesForKind(String? kind);
}

/// Feature-owned data backend for `kit.list`.
///
/// Register via [HostListRegistry] — kit never hardcodes product ids.
abstract class KitListSource {
  const KitListSource();

  String get id;

  /// Catalog hub plugin id used to pipe enrich companions (may be null).
  /// Live Sports / My List host sources leave this null — packs own plugin ids.
  String? get hubPluginId;

  /// When true, [KitShell] mounts [buildHostBody] instead of the plain
  /// [KitListWidget] (list+panel hosts such as Live Sports).
  bool get wantsHostBody => false;

  /// Full-page host composition for [wantsHostBody] sources. Default unused.
  Widget? buildHostBody({
    required String tabId,
    required String pluginId,
    required List<Map<String, dynamic>> layoutWidgets,
    required int refreshEpoch,
    required bool shellTabVisible,
  }) =>
      null;

  /// Optional layout menu filters (`catalog` / `horizon` ids → selected value).
  /// Default no-op — host sources that care sync prefs from kit chrome.
  void onLayoutFilters(WidgetRef ref, Map<String, String> filters) {}

  /// One-shot pending entry id to select after page load (cross-hub open).
  String? takePendingSelectEntryId() => null;

  AsyncValue<KitListPage> watchPage(WidgetRef ref, String status);

  void setupSideEffects(WidgetRef ref, String status);

  void invalidateOnRefresh(WidgetRef ref);

  Future<void> openEntry(BuildContext context, KitListEntry entry);

  Widget? buildEntryPin(
    BuildContext context,
    KitListEntry entry,
    String tabStatus,
  );
}
