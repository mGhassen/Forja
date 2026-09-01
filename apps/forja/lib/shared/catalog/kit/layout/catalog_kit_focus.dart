import 'package:flutter/foundation.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';

VoidCallback? catalogKitFocusEdge(
  String tabId,
  String? rowId, {
  bool last = false,
}) {
  if (rowId == null || rowId.isEmpty) return null;
  return () {
    if (last) {
      final handle = ShellTvFocusCoordinator.rowHandle(tabId, rowId);
      if (handle == null || handle.itemCount <= 0) return;
      final idx = handle.lastFocusedIndex.clamp(0, handle.itemCount - 1);
      ShellTvFocusCoordinator.focusRowItem(tabId, rowId, idx);
      return;
    }
    ShellTvFocusCoordinator.focusRowItem(tabId, rowId, 0);
  };
}
