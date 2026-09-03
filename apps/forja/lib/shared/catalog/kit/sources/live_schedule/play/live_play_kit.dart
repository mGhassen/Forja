import 'package:flutter/material.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shell/shell_bus.dart';

/// Play / details entry for Live Sports meta (`open.surface: live`).
///
/// In-hub card taps use [play/live_play_dispatch.dart]. Cross-hub meta switches
/// to the Live Sports tab and opens the matching fixture when found (RFC-073).
abstract final class LivePlayKit {
  LivePlayKit._();

  static const surface = 'live';

  /// Pending fixture id from [openFromCatalogMeta] until the hub consumes it.
  static String? pendingOpenMatchId;

  static bool isLiveMeta(CatalogMetaItem item) =>
      item.open?.surface == surface || item.type == 'live_match';

  static void openFromCatalogMeta(BuildContext context, CatalogMetaItem item) {
    final id = (item.open?.id ?? item.id).trim();
    pendingOpenMatchId = id.isEmpty ? null : id;
    ShellBus.requestTab.value = 'live_matches';
  }

  /// Hub calls after schedule load — returns and clears [pendingOpenMatchId].
  static String? takePendingOpenMatchId() {
    final id = pendingOpenMatchId;
    pendingOpenMatchId = null;
    return id;
  }
}
