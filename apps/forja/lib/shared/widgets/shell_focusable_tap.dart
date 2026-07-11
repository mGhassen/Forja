import 'package:flutter/material.dart';

import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';

/// Left D-pad from the first item in a horizontal row → active shell nav tab.
VoidCallback? shellTvNavLeftEdge(
  BuildContext context, {
  int listIndex = -1,
  bool navLeftAlways = false,
}) {
  final policy = ShellScope.maybeOf(context)?.inputPolicy;
  final tvFocus = policy?.useFocusableMoodChips ??
      resolveShellProfile(context) == ShellProfile.tv;
  if (!tvFocus) return null;
  if (!navLeftAlways && listIndex != 0) return null;
  return ShellTvFocusCoordinator.focusActiveNavTab;
}

/// Left D-pad from the first column in a grid → active shell nav tab.
VoidCallback? shellTvNavLeftEdgeGrid(
  BuildContext context, {
  required int index,
  required int columnCount,
}) {
  final policy = ShellScope.maybeOf(context)?.inputPolicy;
  final tvFocus = policy?.useFocusableMoodChips ??
      resolveShellProfile(context) == ShellProfile.tv;
  if (!tvFocus) return null;
  if (columnCount <= 0 || index % columnCount != 0) return null;
  return ShellTvFocusCoordinator.focusActiveNavTab;
}

int shellGridColumnCount({
  required double viewportWidth,
  required double itemStride,
  double horizontalPadding = 0,
}) {
  final inner = (viewportWidth - horizontalPadding).clamp(0.0, double.infinity);
  if (itemStride <= 0) return 1;
  return (inner / itemStride).floor().clamp(1, 999);
}

VoidCallback? _resolveTvNavLeftEdge(
  BuildContext context, {
  VoidCallback? onLeftEdge,
  int? listIndex,
  bool navLeftAlways = false,
  int? gridIndex,
  int? gridColumns,
}) {
  if (onLeftEdge != null) return onLeftEdge;
  if (gridIndex != null && gridColumns != null) {
    return shellTvNavLeftEdgeGrid(
      context,
      index: gridIndex,
      columnCount: gridColumns,
    );
  }
  if (listIndex != null || navLeftAlways) {
    return shellTvNavLeftEdge(
      context,
      listIndex: listIndex ?? -1,
      navLeftAlways: navLeftAlways,
    );
  }
  return null;
}

ShellTvFocusMeta? _resolveTvMeta({
  required String? tabId,
  required String? tvRowId,
  required int? tvItemIndex,
  required ShellTvZone? tvZone,
}) {
  if (tabId == null || tabId.isEmpty) return null;
  final zone = tvZone ??
      (tvRowId != null ? ShellTvZone.row : null);
  if (zone == null) return null;
  return ShellTvFocusMeta(
    tabId: tabId,
    zone: zone,
    rowId: tvRowId,
    itemIndex: tvItemIndex,
  );
}

/// TV: [FocusableControl] with D-pad focus lift. Desktop: [InkWell] + optional hover.
Widget shellFocusableTap({
  required BuildContext context,
  required Widget child,
  VoidCallback? onTap,
  double borderRadius = 12,
  double scaleOnFocus = ShellTokens.focusActiveScale,
  VoidCallback? onLeftEdge,
  VoidCallback? onUpEdge,
  VoidCallback? onDownEdge,
  VoidCallback? onRightEdge,
  ValueChanged<bool>? onFocusChange,
  ValueChanged<bool>? onHoverChange,
  FocusNode? focusNode,
  int? listIndex,
  bool navLeftAlways = false,
  int? gridIndex,
  int? gridColumns,
  String? tvTabId,
  String? tvRowId,
  int? tvItemIndex,
  ShellTvZone? tvZone,
  ShellTvEnsureVisibleMode ensureVisibleMode = ShellTvEnsureVisibleMode.row,
}) {
  final policy =
      ShellScope.maybeOf(context)?.inputPolicy ?? ShellInputPolicy.desktop;
  final resolvedLeftEdge = _resolveTvNavLeftEdge(
    context,
    onLeftEdge: onLeftEdge,
    listIndex: listIndex,
    navLeftAlways: navLeftAlways,
    gridIndex: gridIndex,
    gridColumns: gridColumns,
  );
  final tabId = tvTabId ?? ShellTvFocus.currentNavTabId;
  final tvMeta = _resolveTvMeta(
    tabId: tabId,
    tvRowId: tvRowId,
    tvItemIndex: tvItemIndex ?? listIndex ?? gridIndex,
    tvZone: tvZone,
  );

  if (policy.useFocusableMoodChips) {
    return FocusableControl(
      onTap: onTap,
      borderRadius: borderRadius,
      scaleOnFocus: scaleOnFocus,
      onLeftEdge: resolvedLeftEdge,
      onUpEdge: onUpEdge,
      onDownEdge: onDownEdge,
      onRightEdge: onRightEdge,
      onFocusChange: onFocusChange,
      focusNode: focusNode,
      tvMeta: tvMeta,
      ensureVisibleMode: ensureVisibleMode,
      child: child,
    );
  }

  Widget body = Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(borderRadius),
    child: InkWell(
      borderRadius: BorderRadius.circular(borderRadius),
      onTap: onTap,
      child: child,
    ),
  );

  if (policy.scaleOnHover && onHoverChange != null) {
    body = MouseRegion(
      onEnter: (_) => onHoverChange(true),
      onExit: (_) => onHoverChange(false),
      cursor: SystemMouseCursors.click,
      child: body,
    );
  }

  return body;
}

/// Registers a horizontal catalog row with the TV coordinator for vertical moves.
void shellTvRegisterRow({
  required String tabId,
  required String rowId,
  required int sortOrder,
  required int itemCount,
  VoidCallback? onFocusUp,
}) {
  ShellTvFocusCoordinator.registerRow(
    ShellTvRowHandle(
      tabId: tabId,
      rowId: rowId,
      sortOrder: sortOrder,
      itemCount: itemCount,
      nodeAt: (index) =>
          ShellTvFocusCoordinator.itemNode(tabId, rowId, index),
      onFocusUp: onFocusUp,
    ),
  );
}

void shellTvUnregisterRow({
  required String tabId,
  required String rowId,
}) {
  ShellTvFocusCoordinator.unregisterRow(tabId, rowId);
}

void shellTvUpdateRowCount({
  required String tabId,
  required String rowId,
  required int itemCount,
}) {
  ShellTvFocusCoordinator.updateRowItemCount(tabId, rowId, itemCount);
}

/// D-pad down from a chip strip → results row (its last index), or next row.
VoidCallback shellTvChipDownToRow({
  required String tabId,
  required String chipRowId,
  required String resultsRowId,
}) {
  return () {
    ShellTvFocusCoordinator.focusFromChipStripDown(
      tabId: tabId,
      chipRowId: chipRowId,
      resultsRowId: resultsRowId,
    );
  };
}

/// D-pad up from a results row → chip strip (its last index).
VoidCallback shellTvResultsUpToChips({
  required String tabId,
  required String chipRowId,
}) {
  return () {
    ShellTvFocusCoordinator.focusFromResultsRowUp(
      tabId: tabId,
      chipRowId: chipRowId,
    );
  };
}

/// D-pad right between chips — explicit index step; trap at last chip.
VoidCallback? shellTvChipRightEdge({
  required String tabId,
  required String rowId,
  required int index,
  required int itemCount,
}) {
  if (index >= itemCount - 1) return () {};
  return () {
    ShellTvFocusCoordinator.focusAdjacentInRow(
      tabId: tabId,
      rowId: rowId,
      currentIndex: index,
      right: true,
    );
  };
}

/// D-pad left between chips — explicit index step; index 0 uses nav left.
VoidCallback? shellTvChipLeftEdge(
  BuildContext context, {
  required String tabId,
  required String rowId,
  required int index,
}) {
  if (index <= 0) {
    return shellTvNavLeftEdge(context, listIndex: 0);
  }
  return () {
    ShellTvFocusCoordinator.focusAdjacentInRow(
      tabId: tabId,
      rowId: rowId,
      currentIndex: index,
      right: false,
    );
  };
}
