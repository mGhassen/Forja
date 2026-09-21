import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:flutter/foundation.dart';

/// Focus a pack row by id. Marks [ShellTvFocusCoordinator.markKitEdgeMiss] when
/// the row is missing so [shellTvHandleRowArrows] can fall through instead of
/// swallowing the key (Live schedule → sources-kind with panel closed).
///
/// [last] restores the remembered index on the row.
/// [lastItem] focuses the final index (`itemCount - 1`) — used for pack
/// `focusUpRight` → chrome Portals chip without hardcoding the index.
///
/// [down]: when true, prefer a registered `{rowId}-shuffle` chrome row if it
/// has items (e.g. pack `focusDown: 'because'` → `because-shuffle` when the
/// shuffle control is mounted). ↑ keeps landing on the named rail itself.
VoidCallback? kitFocusEdge(
  String tabId,
  String? rowId, {
  bool last = false,
  bool lastItem = false,
  bool down = false,
}) {
  if (rowId == null || rowId.isEmpty) return null;
  final id = rowId.trim();
  if (id.isEmpty) return null;
  return () {
    var target = id;
    if (down) {
      final chrome = '$id-shuffle';
      final shuffle = ShellTvFocusCoordinator.rowHandle(tabId, chrome);
      if (shuffle != null && shuffle.itemCount > 0) {
        target = chrome;
      }
    }
    final bool ok;
    if (lastItem) {
      final handle = ShellTvFocusCoordinator.rowHandle(tabId, target);
      if (handle == null || handle.itemCount <= 0) {
        ok = false;
      } else {
        final index = handle.itemCount - 1;
        ok = ShellTvFocusCoordinator.focusRowItemRemembered(
          tabId,
          target,
          index: index,
        );
      }
    } else if (last) {
      ok = ShellTvFocusCoordinator.focusRowItemRemembered(tabId, target);
    } else {
      ok = ShellTvFocusCoordinator.focusRowItem(tabId, target, 0);
    }
    if (!ok) ShellTvFocusCoordinator.markKitEdgeMiss();
  };
}

/// Pack `focusLeft` / `focusRight` — restore last index on the named row.
VoidCallback? kitFocusSide(String tabId, Object? rowId) {
  return kitFocusEdge(tabId, rowId?.toString(), last: true);
}
