import 'package:flutter/material.dart';
import 'package:forja/shared/foundation/protocol/protocol.dart';
import 'package:forja/shell/bus/shell_bus.dart';

/// Play / details entry for Live Sports meta (`open.surface: live`).
///
/// Cross-hub open switches to the Live Sports tab; [KitListWidget]
/// consumes [pendingOpenMatchId] and opens the streams panel (RFC-073 A09).
abstract final class LivePlayKit {
  LivePlayKit._();

  static const surface = 'live';

  /// Pending fixture id from [openFromMeta] until the hub consumes it.
  static String? pendingOpenMatchId;

  static bool isLiveMeta(MetaItem item) =>
      item.open?.surface == surface || item.type == 'live_match';

  static void openFromMeta(BuildContext context, MetaItem item) {
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
