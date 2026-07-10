import 'package:flutter/material.dart';

import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';

/// Left D-pad from the first item in a horizontal row → shell nav rail.
VoidCallback? shellTvNavLeftEdge(
  BuildContext context, {
  int listIndex = -1,
  bool navLeftAlways = false,
}) {
  if (!ShellScope.inputPolicyOf(context).useFocusableMoodChips) return null;
  if (!navLeftAlways && listIndex != 0) return null;
  return ShellTvFocus.focusCurrentNavTab;
}

/// Left D-pad from the first column in a grid → shell nav rail.
VoidCallback? shellTvNavLeftEdgeGrid(
  BuildContext context, {
  required int index,
  required int columnCount,
}) {
  if (!ShellScope.inputPolicyOf(context).useFocusableMoodChips) return null;
  if (columnCount <= 0 || index % columnCount != 0) return null;
  return ShellTvFocus.focusCurrentNavTab;
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

/// TV: [FocusableControl] with D-pad focus lift. Phone/desktop: plain [InkWell].
Widget shellFocusableTap({
  required BuildContext context,
  required Widget child,
  VoidCallback? onTap,
  double borderRadius = 12,
  double scaleOnFocus = ShellTokens.focusActiveScale,
  VoidCallback? onLeftEdge,
  VoidCallback? onUpEdge,
  ValueChanged<bool>? onFocusChange,
  FocusNode? focusNode,
  int? listIndex,
  bool navLeftAlways = false,
  int? gridIndex,
  int? gridColumns,
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
  if (policy.useFocusableMoodChips) {
    return FocusableControl(
      onTap: onTap,
      borderRadius: borderRadius,
      scaleOnFocus: scaleOnFocus,
      onLeftEdge: resolvedLeftEdge,
      onUpEdge: onUpEdge,
      onFocusChange: onFocusChange,
      focusNode: focusNode,
      child: child,
    );
  }
  return Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(borderRadius),
    child: InkWell(
      borderRadius: BorderRadius.circular(borderRadius),
      onTap: onTap,
      child: child,
    ),
  );
}
