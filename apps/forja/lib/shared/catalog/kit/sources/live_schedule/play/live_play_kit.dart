import 'package:flutter/material.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shell/shell_bus.dart';

/// Play / details entry for Live Sports meta (`open.surface: live`).
///
/// In-hub card taps use [play/live_play_dispatch.dart] (panels, sheets, embed,
/// IPTV handoff). Cross-hub meta switches to the Live Sports tab (RFC-071).
abstract final class LivePlayKit {
  LivePlayKit._();

  static const surface = 'live';

  static bool isLiveMeta(CatalogMetaItem item) =>
      item.open?.surface == surface || item.type == 'live_match';

  static void openFromCatalogMeta(BuildContext context, CatalogMetaItem item) {
    ShellBus.requestTab.value = 'live_matches';
  }
}
