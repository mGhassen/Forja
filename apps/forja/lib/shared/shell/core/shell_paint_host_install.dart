import 'package:flutter/material.dart';
import 'package:forja/shared/navigation/desktop_trackpad_nav.dart';
import 'package:forja/shared/shell/core/shell_paint_host.dart';
import 'package:forja/shared/shell/focus/shell_focusable_tap.dart';
import 'package:forja/shared/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/shell/tv/tv_focus_graph.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

/// Wire host TV/focus into [ShellPaintScope]. Call once at app bootstrap.
void installShellPaintHostAdapters() {
  registerShellPaintHostAdapters(
    isActivateKey: shellTvIsActivateKey,
    absorbHorizontalScroll: shellAbsorbHorizontalScroll,
    wrapHorizontalScroller: (child) => DesktopSwipeBackIgnore(child: child),
    wrapTvRow: ({
      required String tabId,
      required String rowId,
      required int sortOrder,
      required int itemCount,
      VoidCallback? onFocusUp,
      VoidCallback? onFocusDown,
      required Widget child,
    }) {
      return TvKitRow(
        tabId: tabId,
        rowId: rowId,
        sortOrder: sortOrder,
        itemCount: itemCount,
        onFocusUp: onFocusUp,
        onFocusDown: onFocusDown,
        child: child,
      );
    },
    focusableTap: ({
      required BuildContext context,
      required Widget child,
      VoidCallback? onTap,
      double borderRadius = 12,
      double scaleOnFocus = 1.04,
      VoidCallback? onLeftEdge,
      VoidCallback? onUpEdge,
      VoidCallback? onDownEdge,
      VoidCallback? onRightEdge,
      ValueChanged<bool>? onFocusChange,
      ValueChanged<bool>? onHoverChange,
      FocusNode? focusNode,
      bool autoFocus = false,
      int? listIndex,
      bool navLeftAlways = false,
      int? gridIndex,
      int? gridColumns,
      String? tvTabId,
      String? tvRowId,
      int? tvItemIndex,
      ShellPaintTvZone? tvZone,
      ShellPaintEnsureVisible ensureVisibleMode = ShellPaintEnsureVisible.row,
      bool showFocusBorder = false,
      bool showFocusFill = true,
      bool showFocusRail = false,
      bool suppressInkHover = false,
      FocusOnKeyEventCallback? onKeyEvent,
    }) {
      return shellFocusableTap(
        context: context,
        child: child,
        onTap: onTap,
        borderRadius: borderRadius,
        scaleOnFocus: scaleOnFocus == 1.04
            ? ShellTokens.focusActiveScale
            : scaleOnFocus,
        onLeftEdge: onLeftEdge,
        onUpEdge: onUpEdge,
        onDownEdge: onDownEdge,
        onRightEdge: onRightEdge,
        onFocusChange: onFocusChange,
        onHoverChange: onHoverChange,
        focusNode: focusNode,
        autoFocus: autoFocus,
        listIndex: listIndex,
        navLeftAlways: navLeftAlways,
        gridIndex: gridIndex,
        gridColumns: gridColumns,
        tvTabId: tvTabId,
        tvRowId: tvRowId,
        tvItemIndex: tvItemIndex,
        tvZone: _mapZone(tvZone),
        ensureVisibleMode: ensureVisibleMode,
        showFocusBorder: showFocusBorder,
        showFocusFill: showFocusFill,
        showFocusRail: showFocusRail,
        suppressInkHover: suppressInkHover,
        onKeyEvent: onKeyEvent,
      );
    },
  );
}

ShellTvZone? _mapZone(ShellPaintTvZone? zone) {
  if (zone == null) return null;
  return switch (zone) {
    ShellPaintTvZone.nav => ShellTvZone.nav,
    ShellPaintTvZone.hero => ShellTvZone.hero,
    ShellPaintTvZone.topBar => ShellTvZone.topBar,
    ShellPaintTvZone.chipStrip => ShellTvZone.chipStrip,
    ShellPaintTvZone.row => ShellTvZone.row,
    ShellPaintTvZone.grid => ShellTvZone.grid,
    ShellPaintTvZone.settings => ShellTvZone.settings,
  };
}
