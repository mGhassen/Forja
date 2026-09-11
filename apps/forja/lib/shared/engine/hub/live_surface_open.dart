import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja/shared/engine/hub/kit_live_boot.dart';
import 'package:forja/shell/bus/shell_bus.dart';

/// Host route for `open.surface: live`.
///
/// Switches to the hub tab that declares engine type `live_match`.
/// [KitListWidget] consumes [pendingOpenEntryId] after the list loads.
abstract final class LiveSurfaceOpen {
  LiveSurfaceOpen._();

  static const surface = 'live';

  static String? pendingOpenEntryId;

  static bool isLiveMeta(MetaItem item) =>
      item.open?.surface == surface || item.type == 'live_match';

  static void openFromMeta(BuildContext context, MetaItem item) {
    final id = (item.open?.id ?? item.id).trim();
    pendingOpenEntryId = id.isEmpty ? null : id;
    unawaited(_requestTab());
  }

  static Future<void> _requestTab() async {
    final tab = await KitLiveBoot.resolveTabId();
    if (tab == null || tab.isEmpty) return;
    ShellBus.requestTab.value = tab;
  }

  static String? takePendingOpenEntryId() {
    final id = pendingOpenEntryId;
    pendingOpenEntryId = null;
    return id;
  }
}
