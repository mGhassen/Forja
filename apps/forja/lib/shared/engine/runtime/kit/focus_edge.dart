import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:flutter/foundation.dart';

/// Focus a pack row by id. Marks [ShellTvFocusCoordinator.markKitEdgeMiss] when
/// the row is missing so [shellTvHandleRowArrows] can fall through instead of
/// swallowing the key (Live schedule → sources-kind with panel closed).
VoidCallback? kitFocusEdge(
  String tabId,
  String? rowId, {
  bool last = false,
}) {
  if (rowId == null || rowId.isEmpty) return null;
  final id = rowId.trim();
  if (id.isEmpty) return null;
  return () {
    final ok = last
        ? ShellTvFocusCoordinator.focusRowItemRemembered(tabId, id)
        : ShellTvFocusCoordinator.focusRowItem(tabId, id, 0);
    if (!ok) ShellTvFocusCoordinator.markKitEdgeMiss();
  };
}

/// Pack `focusLeft` / `focusRight` — restore last index on the named row.
VoidCallback? kitFocusSide(String tabId, Object? rowId) {
  return kitFocusEdge(tabId, rowId?.toString(), last: true);
}
