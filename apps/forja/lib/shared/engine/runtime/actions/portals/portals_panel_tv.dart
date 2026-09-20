import 'package:flutter/material.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shell/tv/shell_tv_focus.dart';
import 'package:forja_foundation/widgets/chrome/portal_list_row.dart';
import 'package:forja_foundation/widgets/chrome/portal_list_view.dart';

/// Host TV focus graph for [PortalListView] — I147 handoff / no-steal / jump.
///
/// Foundation paints; this owns coordinator calls + scroll jump.
class PortalsPanelTvFocus {
  PortalsPanelTvFocus({required this.tabId, this.rowHeight});

  final String tabId;
  double? rowHeight;
  final listScroll = ScrollController();

  /// Open-time focus handoff consumed once — later notifies must not re-steal.
  bool didFocusOnOpen = false;
  String? scrolledToActiveKey;
  int? scrolledToActiveIndex;
  int? lastFocusedPortalIndex;
  bool pointerBrowsingList = false;

  static const _listFocusMargin = 8.0;

  void dispose() {
    listScroll.dispose();
  }

  void resetOnClose() {
    didFocusOnOpen = false;
    scrolledToActiveKey = null;
    scrolledToActiveIndex = null;
    lastFocusedPortalIndex = null;
    pointerBrowsingList = false;
  }

  bool rowHasFocus(String rowId) {
    final handle = ShellTvFocusCoordinator.rowHandle(tabId, rowId);
    if (handle == null || handle.itemCount <= 0) return false;
    for (var i = 0; i < handle.itemCount; i++) {
      if (handle.nodeAt(i)?.hasFocus ?? false) return true;
    }
    return false;
  }

  bool focusRow(String rowId, [int? index]) {
    final handle = ShellTvFocusCoordinator.rowHandle(tabId, rowId);
    if (handle == null || handle.itemCount <= 0) return false;
    final idx =
        (index ?? handle.lastFocusedIndex).clamp(0, handle.itemCount - 1);
    return ShellTvFocusCoordinator.focusRowItem(tabId, rowId, idx);
  }

  bool focusRowExact(String rowId, int index) =>
      ShellTvFocusCoordinator.focusRowItemExact(tabId, rowId, index);

  int headerAddIndex({required int headerActionCount}) {
    // Search (0) + pack header actions (Scrape/Deal/Add…) — Add is last.
    return headerActionCount; // search + N actions → last index = N
  }

  int entryIndex({
    required int filteredLength,
    required int activeIndex,
  }) {
    final last = lastFocusedPortalIndex;
    if (last != null && last >= 0 && last < filteredLength) return last;
    if (activeIndex >= 0 && activeIndex < filteredLength) return activeIndex;
    return 0;
  }

  void jumpToIndex(int index) {
    if (!listScroll.hasClients || index < 0) return;
    final position = listScroll.position;
    final viewport = position.viewportDimension;
    if (viewport <= 0) return;
    final itemTop = index * (rowHeight ?? PortalListRow.rowHeight);
    final itemBottom = itemTop + (rowHeight ?? PortalListRow.rowHeight);
    final viewTop = position.pixels;
    final viewBottom = viewTop + viewport;
    double? target;
    if (itemTop < viewTop + _listFocusMargin) {
      target = itemTop - _listFocusMargin;
    } else if (itemBottom > viewBottom - _listFocusMargin) {
      target = itemBottom - viewport + _listFocusMargin;
    }
    if (target == null) return;
    listScroll.jumpTo(target.clamp(0.0, position.maxScrollExtent));
  }

  void focusPortalAt({
    required int index,
    required int total,
    required bool mounted,
  }) {
    if (!mounted || total <= 0) return;
    final clamped = index.clamp(0, total - 1);
    lastFocusedPortalIndex = clamped;
    pointerBrowsingList = false;
    jumpToIndex(clamped);
    if (focusRowExact(PortalListView.portalsRowId, clamped)) return;
    var tries = 0;
    void attempt() {
      if (!mounted) return;
      if (focusRowExact(PortalListView.portalsRowId, clamped)) return;
      jumpToIndex(clamped);
      if (tries++ < 12) {
        WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
  }

  void focusPortalsFromHeader({
    required int filteredLength,
    required int activeIndex,
    required bool mounted,
  }) {
    var tries = 0;
    void attempt() {
      if (!mounted) return;
      if (filteredLength <= 0) {
        if (tries++ < 32) {
          WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
        }
        return;
      }
      final index = entryIndex(
        filteredLength: filteredLength,
        activeIndex: activeIndex,
      );
      // Scroll before focusing: an already-mounted row takes focus fine while
      // staying off-screen, which is how the chip used to land on an unseen
      // active portal. No-op once the row sits inside the viewport.
      jumpToIndex(index);
      if (focusRowExact(PortalListView.portalsRowId, index)) {
        lastFocusedPortalIndex = index;
        // The list often attaches its scroll position only on this frame.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) jumpToIndex(index);
        });
        return;
      }
      if (tries++ < 16) {
        WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
        return;
      }
      focusRow(PortalListView.portalsRowId, 0);
    }

    attempt();
  }

  void focusPanelOnOpen({
    required int filteredLength,
    required int activeIndex,
    required int headerActionCount,
    required bool mounted,
    required bool searchOpen,
  }) {
    if (!mounted || searchOpen) return;
    if (rowHasFocus(PortalListView.portalsRowId) ||
        rowHasFocus(PortalListView.headerRowId)) {
      return;
    }
    if (filteredLength <= 0) {
      var tries = 0;
      void waitForList() {
        if (!mounted || searchOpen) return;
        if (rowHasFocus(PortalListView.portalsRowId) ||
            rowHasFocus(PortalListView.headerRowId)) {
          return;
        }
        if (filteredLength > 0) {
          focusPortalsFromHeader(
            filteredLength: filteredLength,
            activeIndex: activeIndex,
            mounted: mounted,
          );
          return;
        }
        if (tries++ < 32) {
          WidgetsBinding.instance.addPostFrameCallback((_) => waitForList());
          return;
        }
        focusHeaderAdd(headerActionCount: headerActionCount);
      }

      waitForList();
      return;
    }
    focusPortalsFromHeader(
      filteredLength: filteredLength,
      activeIndex: activeIndex,
      mounted: mounted,
    );
  }

  void focusHeaderAdd({required int headerActionCount}) {
    final addIndex = headerAddIndex(headerActionCount: headerActionCount);
    if (focusRow(PortalListView.headerRowId, addIndex)) return;
    focusRow(PortalListView.headerRowId, 0);
  }

  void focusHeaderAt(int index) {
    focusRowExact(PortalListView.headerRowId, index);
  }

  void onPortalLeft() {
    // Search is always header index 0 (Search · Scrape · Deal · Add…).
    focusHeaderAt(0);
  }

  void onPortalMove({
    required int fromIndex,
    required int deltaSign,
    required int total,
    required bool mounted,
  }) {
    if (total <= 0) return;
    final step = ShellTvHoldAccel.lastStep;
    final delta = deltaSign < 0 ? -step : step;
    focusPortalAt(
      index: fromIndex + delta,
      total: total,
      mounted: mounted,
    );
  }

  void onListPointerBrowse() {
    pointerBrowsingList = true;
  }

  void markPortalTvFocus(int index) {
    lastFocusedPortalIndex = index;
    pointerBrowsingList = false;
  }

  /// After inventory rebuild (health / scrape) — no steal while browsing.
  void onInventoryChanged({
    required bool panelOpen,
    required bool searchOpen,
    required int filteredLength,
    required String? activeKey,
    required int activeIndex,
    required Set<String> currentKeys,
    required Set<String> knownKeys,
    required void Function(Set<String> next) setKnownKeys,
    required bool mounted,
  }) {
    if (!panelOpen) {
      setKnownKeys(currentKeys);
      resetOnClose();
      return;
    }
    final listFocused = rowHasFocus(PortalListView.portalsRowId);
    final userInList = listFocused ||
        lastFocusedPortalIndex != null ||
        pointerBrowsingList;
    final willScrollActive = activeKey != null &&
        activeKey.isNotEmpty &&
        !userInList &&
        (activeKey != scrolledToActiveKey ||
            activeIndex != scrolledToActiveIndex);
    if (willScrollActive && activeIndex >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        jumpToIndex(activeIndex);
        scrolledToActiveKey = activeKey;
        scrolledToActiveIndex = activeIndex;
      });
    }
    setKnownKeys(currentKeys);
    if (lastFocusedPortalIndex != null &&
        !listFocused &&
        !pointerBrowsingList &&
        !rowHasFocus(PortalListView.headerRowId) &&
        filteredLength > 0) {
      final idx = lastFocusedPortalIndex!.clamp(0, filteredLength - 1);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !panelOpen) return;
        if (rowHasFocus(PortalListView.portalsRowId) ||
            rowHasFocus(PortalListView.headerRowId)) {
          return;
        }
        focusPortalAt(index: idx, total: filteredLength, mounted: mounted);
      });
    }
  }

  void exitDownToCatalog() {
    // Vertical panels: last portal ↓ stays in Portals (← / close hop out).
  }

  void exitUpToChip() {
    // Prefer remembered top-bar Portals chip / chrome.
    if (ShellTvFocusCoordinator.focusRowItemRemembered(tabId, 'chrome')) {
      return;
    }
  }
}
