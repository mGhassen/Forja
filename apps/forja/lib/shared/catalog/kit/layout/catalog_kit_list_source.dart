import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/catalog/protocol.dart';

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

/// Feature-owned data backend for `kit.list`.
///
/// Register via [CatalogHostListRegistry] — kit never hardcodes product ids.
abstract class CatalogKitListSource {
  const CatalogKitListSource();

  String get id;

  /// Catalog hub plugin id used to pipe enrich companions (may be null).
  String? get hubPluginId;

  /// When true, [CatalogShell] mounts [buildHostBody] instead of the plain
  /// [CatalogKitListWidget] (list+panel hosts such as Live Sports).
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
