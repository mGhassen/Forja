import 'package:flutter/material.dart';
import 'package:forja/shared/engine/runtime/kit/list/list_source.dart';

/// Side panel for a `kit.list` source.
///
/// Features register an implementation; kit / browse shells never import the
/// product module — they resolve by opaque [listSourceId].
abstract class KitPanelHost {
  /// Opaque id matching [KitListSource.id].
  String get listSourceId;

  /// Streams / details panel beside the dense list for [entry].
  Widget buildSidePanel({
    required BuildContext context,
    required KitListEntry entry,
    required List<Map<String, dynamic>> layoutWidgets,
    required bool shellTabVisible,
    required int refreshEpoch,
    VoidCallback? onClosed,
    /// TV: ← from Providers / Live TV (and stream rows) returns here.
    VoidCallback? onPanelLeftEdge,
  });

  /// Optional full-page details (cards pack). Null → generic scaffold panel.
  Widget? buildDetailsPage({
    required BuildContext context,
    required KitListEntry entry,
    required List<Map<String, dynamic>> layoutWidgets,
    required int refreshEpoch,
  }) =>
      null;
}
