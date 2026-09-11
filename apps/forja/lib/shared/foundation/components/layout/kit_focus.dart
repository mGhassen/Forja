import 'package:flutter/foundation.dart';
import 'package:forja/shared/shell/tv/shell_tv_coordinator.dart';

VoidCallback? kitFocusEdge(
  String tabId,
  String? rowId, {
  bool last = false,
}) {
  if (rowId == null || rowId.isEmpty) return null;
  return () {
    if (last) {
      ShellTvFocusCoordinator.focusRowItemRemembered(tabId, rowId);
      return;
    }
    ShellTvFocusCoordinator.focusRowItem(tabId, rowId, 0);
  };
}
