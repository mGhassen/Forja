export 'package:forja/shared/engine/runtime/details/kit_list_entry.dart';

import 'package:flutter/material.dart';
import 'package:forja/shared/engine/runtime/details/kit_list_entry.dart';

/// Opaque list page contract for resolve/details hosts (no product feed runtime).
abstract class KitListPage {
  bool get loadingRemote;
  String? get loadingProgressLabel;
  int get totalCount;
}

abstract class KitListSource {
  String get id;
  String? get hubPluginId;
}

/// Side panel / details page for an opaque list source id.
abstract class KitPanelHost {
  String get listSourceId;

  Widget? buildDetailsPage({
    required BuildContext context,
    required KitListEntry entry,
    required List<Map<String, dynamic>> layoutWidgets,
    required int refreshEpoch,
  });

  Widget buildSidePanel({
    required BuildContext context,
    required KitListEntry entry,
    required List<Map<String, dynamic>> layoutWidgets,
    required bool shellTabVisible,
    required int refreshEpoch,
    VoidCallback? onClosed,
    VoidCallback? onPanelLeftEdge,
  });
}
