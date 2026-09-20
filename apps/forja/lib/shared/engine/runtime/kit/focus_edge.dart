import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:flutter/foundation.dart';

/// Focus a pack row by id. Marks [ShellTvFocusCoordinator.markKitEdgeMiss] when
/// the row is missing so [shellTvHandleRowArrows] can fall through instead of
/// swallowing the key (Live schedule → sources-kind with panel closed).
///
/// [last] restores the remembered index on the row.
/// [lastItem] focuses the final index (`itemCount - 1`) — used for pack
/// `focusUpRight` → chrome Portals chip without hardcoding the index.
VoidCallback? kitFocusEdge(
  String tabId,
  String? rowId, {
  bool last = false,
  bool lastItem = false,
}) {
  if (rowId == null || rowId.isEmpty) return null;
  final id = rowId.trim();
  if (id.isEmpty) return null;
  return () {
    final bool ok;
    if (lastItem) {
      final handle = ShellTvFocusCoordinator.rowHandle(tabId, id);
      if (handle == null || handle.itemCount <= 0) {
        ok = false;
      } else {
        final index = handle.itemCount - 1;
        ok = ShellTvFocusCoordinator.focusRowItemRemembered(
          tabId,
          id,
          index: index,
        );
      }
    } else if (last) {
      ok = ShellTvFocusCoordinator.focusRowItemRemembered(tabId, id);
    } else {
      ok = ShellTvFocusCoordinator.focusRowItem(tabId, id, 0);
    }
    if (!ok) ShellTvFocusCoordinator.markKitEdgeMiss();
  };
}

/// Pack `focusLeft` / `focusRight` — restore last index on the named row.
VoidCallback? kitFocusSide(String tabId, Object? rowId) {
  return kitFocusEdge(tabId, rowId?.toString(), last: true);
}
