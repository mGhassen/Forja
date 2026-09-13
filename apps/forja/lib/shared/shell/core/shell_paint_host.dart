import 'package:flutter/material.dart';
import 'package:forja/shared/navigation/desktop_trackpad_nav.dart';
import 'package:forja/shared/shell/core/forja_shell_input_policy.dart';
import 'package:forja/shared/shell/core/forja_shell_metrics.dart';
import 'package:forja/shared/shell/focus/shell_focusable_tap.dart';
import 'package:forja/shared/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/shell/tv/tv_focus_graph.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

/// Maps foundation paint focus requests onto host TV/focus chrome.
Widget shellPaintHostScope({
  required ShellInputPolicy inputPolicy,
  required ShellMetrics metrics,
  required Widget child,
}) {
  return ShellPaintScope(
    useTvFocus: inputPolicy.useFocusableMoodChips,
    scaleOnHover: inputPolicy.scaleOnHover,
    usesTvDensity: metrics.usesTvDensity,
    focusStyled: (context, {required focused}) =>
        inputPolicy.focusStyled(context, focused: focused),
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
      String? tvTabId,
      String? tvRowId,
      int? tvItemIndex,
      ShellPaintTvZone? tvZone,
      ShellPaintEnsureVisible ensureVisibleMode = ShellPaintEnsureVisible.row,
      bool showFocusBorder = false,
      bool showFocusFill = true,
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
        tvTabId: tvTabId,
        tvRowId: tvRowId,
        tvItemIndex: tvItemIndex,
        tvZone: _mapZone(tvZone),
        ensureVisibleMode: _mapEnsure(ensureVisibleMode),
        showFocusBorder: showFocusBorder,
        showFocusFill: showFocusFill,
        suppressInkHover: suppressInkHover,
        onKeyEvent: onKeyEvent,
      );
    },
    child: child,
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

ShellTvEnsureVisibleMode _mapEnsure(ShellPaintEnsureVisible mode) {
  return switch (mode) {
    ShellPaintEnsureVisible.off => ShellTvEnsureVisibleMode.off,
    ShellPaintEnsureVisible.row => ShellTvEnsureVisibleMode.row,
    ShellPaintEnsureVisible.item => ShellTvEnsureVisibleMode.item,
  };
}
