import 'package:flutter/foundation.dart';
import 'package:forja/shared/shell/tv/shell_tv_coordinator.dart';

VoidCallback? kitFocusEdge(
  String tabId,
  String? rowId, {
  bool last = false,
}) {
  if (rowId == null || rowId.isEmpty) return null;
  final id = rowId.trim();
  if (id.isEmpty) return null;
  return () {
    if (last) {
      ShellTvFocusCoordinator.focusRowItemRemembered(tabId, id);
      return;
    }
    ShellTvFocusCoordinator.focusRowItem(tabId, id, 0);
  };
}

/// Pack `focusLeft` / `focusRight` — restore last index on the named row.
VoidCallback? kitFocusSide(String tabId, Object? rowId) {
  return kitFocusEdge(tabId, rowId?.toString(), last: true);
}
