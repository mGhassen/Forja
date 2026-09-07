import 'package:flutter/material.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_kit_list_source.dart';

/// Forja platform: side panel for a `kit.list` source (e.g. Live Sports streams).
///
/// Features register an implementation; kit / browse shells never import the
/// product module — they resolve by opaque [listSourceId].
abstract class CatalogKitPanelHost {
  /// Opaque id matching [CatalogKitListSource.id] (e.g. `live_schedule`).
  String get listSourceId;

  /// Streams / details panel beside the dense list for [entry].
  Widget buildSidePanel({
    required BuildContext context,
    required CatalogKitListEntry entry,
    required List<Map<String, dynamic>> layoutWidgets,
    required bool shellTabVisible,
    required int refreshEpoch,
    VoidCallback? onClosed,
  });
}
