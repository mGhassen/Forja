import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:forja/shared/navigation/shell_navigation_levels.dart';
import 'package:forja/shared/tv/media_details_tv_scope.dart';
import 'package:forja/shared/tv/shell_tv_back_exit.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';

/// Focus zone within a shell tab.
enum ShellTvZone {
  nav,
  hero,
  topBar,
  chipStrip,
  row,
  grid,
  settings,
}

/// Last-known TV focus for a tab.
class ShellTvFocusMemory {
  const ShellTvFocusMemory({
    required this.zone,
    this.rowId,
    this.itemIndex = 0,
    this.node,
  });

  final ShellTvZone zone;
  final String? rowId;
  final int itemIndex;
  final FocusNode? node;

  ShellTvFocusMemory copyWith({
    ShellTvZone? zone,
    String? rowId,
    int? itemIndex,
    FocusNode? node,
  }) {
    return ShellTvFocusMemory(
      zone: zone ?? this.zone,
      rowId: rowId ?? this.rowId,
      itemIndex: itemIndex ?? this.itemIndex,
      node: node ?? this.node,
    );
  }
}

/// Horizontal vs vertical item layout within a registered TV row.
enum ShellTvRowOrientation { horizontal, vertical }

/// Horizontal catalog row registered with the coordinator.
class ShellTvRowHandle {
  ShellTvRowHandle({
    required this.tabId,
    required this.rowId,
    required this.sortOrder,
    required this.itemCount,
    required this.nodeAt,
    this.orientation = ShellTvRowOrientation.horizontal,
    this.isFirstRow = false,
    this.isLastRow = false,
    this.onFocusUp,
    this.onFocusDown,
  });

  final String tabId;
  final String rowId;
  final int sortOrder;
  int itemCount;
  int lastFocusedIndex = 0;
  final FocusNode? Function(int index) nodeAt;
  final ShellTvRowOrientation orientation;
  bool isFirstRow;
  bool isLastRow;
  final VoidCallback? onFocusUp;
  final VoidCallback? onFocusDown;
}

/// Central TV D-pad coordinator — nav isolation, row memory, tab restore.
abstract final class ShellTvFocusCoordinator {
  static final Map<String, ShellTvFocusMemory> _tabMemory = {};
  static final Map<String, List<ShellTvRowHandle>> _rowsByTab = {};
  static final List<String> _navOrder = [];

  static VoidCallback? heroReveal;
  static FocusNode? Function(String tabId)? defaultFocusForTab;

  static final Map<String, FocusNode? Function()> _tabDefaultFocus = {};
  static final Map<String, VoidCallback> _tabHeroReveal = {};
  static final Map<String, VoidCallback> _tabEnterFocus = {};
  static final Map<String, bool Function()> _tabRestoreFocus = {};

  /// Per-tab default focus and hero scroll — survives multi-tab mount order.
  static void registerTabDefaults(
    String tabId, {
    FocusNode? Function()? defaultFocus,
    VoidCallback? heroReveal,
    VoidCallback? enterFromNavFocus,
    bool Function()? restoreFocus,
  }) {
    if (defaultFocus != null) _tabDefaultFocus[tabId] = defaultFocus;
    if (heroReveal != null) _tabHeroReveal[tabId] = heroReveal;
    if (enterFromNavFocus != null) _tabEnterFocus[tabId] = enterFromNavFocus;
    if (restoreFocus != null) _tabRestoreFocus[tabId] = restoreFocus;
  }

  static void unregisterTabDefaults(String tabId) {
    _tabDefaultFocus.remove(tabId);
    _tabHeroReveal.remove(tabId);
    _tabEnterFocus.remove(tabId);
    _tabRestoreFocus.remove(tabId);
  }

  /// Nav Enter on a tab — e.g. search field browse focus (not last page memory).
  static bool focusTabEnterFromNav(String tabId) {
    final enter = _tabEnterFocus[tabId];
    if (enter == null) return false;
    enter();
    return true;
  }

  // --- Nav order ---

  static void setNavOrder(List<String> ids) {
    _navOrder
      ..clear()
      ..addAll(ids);
  }

  static List<String> get navOrder => List.unmodifiable(_navOrder);

  static int? _navIndexForId(String? id) {
    if (id == null) return null;
    final idx = _navOrder.indexOf(id);
    return idx >= 0 ? idx : null;
  }

  static String? _navIdAt(int index) {
    if (index < 0 || index >= _navOrder.length) return null;
    return _navOrder[index];
  }

  static FocusNode? _navNodeForId(String? id) {
    if (id == null) return null;
    return ShellTvFocus.navNode(id);
  }

  static String? _focusedNavId() {
    for (final id in _navOrder) {
      final node = ShellTvFocus.navNode(id);
      if (node?.hasFocus ?? false) return id;
    }
    return null;
  }

  static bool focusActiveNavTab() => ShellTvFocus.focusCurrentNavTab();

  /// TV remote Back: pop overlay/route first, else focus active nav tab.
  /// Second Back on nav requests app exit. Returns true when consumed.
  static VoidCallback? onRequestExitApp;

  /// Set from [ShellScaffold] when TV input policy is active — same signal as
  /// shell nav rail / D-pad focus (not [ShellTokens.isAndroidTvDevice] alone).
  static bool tvBackPolicyEnabled = false;

  static DateTime? _lastBackHandledAt;
  static const Duration _backDebounceWindow = Duration(milliseconds: 400);

  /// Test-only — clears back debounce between widget tests.
  static void resetBackDebounceForTest() {
    _lastBackHandledAt = null;
  }

  static bool _consumeDuplicateBack() {
    final now = DateTime.now();
    final last = _lastBackHandledAt;
    if (last != null && now.difference(last) < _backDebounceWindow) {
      return true;
    }
    _lastBackHandledAt = now;
    return false;
  }

  /// Level-aware back — see [ShellNavigationLevels].
  /// Always returns true when [tvBackPolicyEnabled] (never delegates kill to caller).
  static bool handleShellBackKey() {
    if (_consumeDuplicateBack()) return true;

    if (!tvBackPolicyEnabled) {
      return _handleLegacyBackKey();
    }

    switch (ShellNavigationLevels.resolveBackTarget()) {
      case ShellNavLevel.player:
        ShellTvBackExit.reset();
        ShellNavigationLevels.popRootRoute();
        return true;
      case ShellNavLevel.detail:
        ShellTvBackExit.reset();
        maybePopShellOverlay();
        return true;
      case ShellNavLevel.tabStack:
        ShellTvBackExit.reset();
        if (ShellNavigationLevels.popTabStack()) return true;
        _focusActiveNavFromPage();
        return true;
      case ShellNavLevel.page:
        ShellTvBackExit.reset();
        _focusActiveNavFromPage();
        return true;
      case ShellNavLevel.menu:
        ShellTvBackExit.onNavBack(onRequestExitApp ?? SystemNavigator.pop);
        return true;
    }
  }

  static bool _handleLegacyBackKey() {
    if (shellOverlayCanPop()) {
      ShellTvBackExit.reset();
      maybePopShellOverlay();
      return true;
    }

    if (_tryPopFocusedNavigator()) {
      ShellTvBackExit.reset();
      return true;
    }

    if (ShellTvFocus.currentNavTabId == null) {
      if (tvBackPolicyEnabled) {
        _focusActiveNavFromPage();
        return true;
      }
      return false;
    }

    if (ShellTvFocus.anyNavFocused || ShellTvFocus.primaryFocusIsNav) {
      ShellTvBackExit.onNavBack(onRequestExitApp ?? SystemNavigator.pop);
      return true;
    }

    ShellTvBackExit.reset();
    _focusActiveNavFromPage();
    return true;
  }

  static void _focusActiveNavFromPage() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (focusActiveNavTab()) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusActiveNavTab();
    });
  }

  static bool _tryPopFocusedNavigator() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;

    final nav = Navigator.maybeOf(ctx);
    if (nav != null && nav.canPop()) {
      nav.maybePop();
      return true;
    }

    final rootNav = Navigator.maybeOf(ctx, rootNavigator: true);
    if (rootNav != null && rootNav != nav && rootNav.canPop()) {
      rootNav.maybePop();
      return true;
    }
    return false;
  }

  static bool focusNextNavItem() {
    final current = _focusedNavId() ?? ShellTvFocus.currentNavTabId;
    final idx = _navIndexForId(current);
    if (idx == null) return false;
    if (idx >= _navOrder.length - 1) return false;
    final next = _navNodeForId(_navIdAt(idx + 1));
    if (next == null || !next.canRequestFocus) return false;
    next.requestFocus();
    return true;
  }

  static bool focusPrevNavItem() {
    final current = _focusedNavId() ?? ShellTvFocus.currentNavTabId;
    final idx = _navIndexForId(current);
    if (idx == null || idx <= 0) return false;
    final prev = _navNodeForId(_navIdAt(idx - 1));
    if (prev == null || !prev.canRequestFocus) return false;
    prev.requestFocus();
    return true;
  }

  static bool handleNavKey(LogicalKeyboardKey key) {
    return switch (key) {
      LogicalKeyboardKey.arrowDown => focusNextNavItem(),
      LogicalKeyboardKey.arrowUp => focusPrevNavItem(),
      LogicalKeyboardKey.arrowLeft => true, // trap
      LogicalKeyboardKey.arrowRight => _restorePageFromNav(
          ShellTvFocus.currentNavTabId ?? '',
        ),
      _ => false,
    };
  }

  /// Nav RIGHT — return to the active tab page without switching tabs.
  static bool _restorePageFromNav(String tabId) {
    restoreTabFocusAfterNav(_navRestoreTabId(tabId));
    return true;
  }

  /// Overlay routes (details, search) own their own TV tab memory.
  static String _navRestoreTabId(String shellTabId) {
    if (!shellOverlayCanPop()) return shellTabId;
    final detailsRows = _rowsByTab[MediaDetailsTv.tabId];
    if (detailsRows != null && detailsRows.isNotEmpty) {
      return MediaDetailsTv.tabId;
    }
    if (_tabMemory.containsKey('search') ||
        (_rowsByTab['search']?.isNotEmpty ?? false)) {
      return 'search';
    }
    return shellTabId;
  }

  /// Release nav and restore page focus after the rail handles RIGHT.
  static void restoreTabFocusAfterNav(String tabId) {
    if (tabId.isEmpty) return;
    ShellTvBackExit.reset();
    _releaseNavFocus();
    void attempt() {
      if (!restoreTabFocus(tabId)) {
        _restoreDefault(tabId);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      attempt();
      if (!_pageHasFocus()) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _releaseNavFocus();
          attempt();
        });
      }
    });
  }

  static void _releaseNavFocus() {
    if (!ShellTvFocus.anyNavFocused && !ShellTvFocus.primaryFocusIsNav) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
  }

  static bool _pageHasFocus() {
    if (ShellTvFocus.anyNavFocused || ShellTvFocus.primaryFocusIsNav) {
      return false;
    }
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return false;
    final ctx = primary.context;
    return ctx != null && ctx.mounted;
  }

  static void _revealHeroForTab(String tabId) {
    _tabHeroReveal[tabId]?.call();
    if (!_tabHeroReveal.containsKey(tabId)) {
      heroReveal?.call();
    }
  }

  /// Scroll the active tab's hero into view (e.g. when a hero CTA gains focus).
  static void revealHeroForTab(String tabId) => _revealHeroForTab(tabId);

  // --- Tab memory ---

  static void saveFocus(String tabId, ShellTvFocusMemory memory) {
    if (tabId.isEmpty) return;
    _tabMemory[tabId] = memory;
  }

  static ShellTvFocusMemory? memoryFor(String tabId) => _tabMemory[tabId];

  static bool restoreTabFocus(String tabId) {
    if (tabId.isEmpty) return false;
    final custom = _tabRestoreFocus[tabId];
    if (custom != null && custom()) {
      return _pageHasFocus();
    }
    final memory = _tabMemory[tabId];
    if (memory != null && memory.zone != ShellTvZone.nav) {
      if (_restoreFromMemory(tabId, memory) && _pageHasFocus()) {
        return true;
      }
      if (_tryRestoreLiveNode(memory) && _pageHasFocus()) {
        return true;
      }
    }
    return _restoreDefault(tabId);
  }

  static bool _tryRestoreLiveNode(ShellTvFocusMemory memory) {
    final node = memory.node;
    if (node == null || !node.canRequestFocus) return false;
    final ctx = node.context;
    if (ctx == null || !ctx.mounted) return false;
    return _request(node);
  }

  static bool _restoreFromMemory(String tabId, ShellTvFocusMemory memory) {
    switch (memory.zone) {
      case ShellTvZone.hero:
        return focusHero(revealFull: true, tabId: tabId);
      case ShellTvZone.row:
        if (memory.rowId != null) {
          return focusRowItem(tabId, memory.rowId!, memory.itemIndex);
        }
        return _restoreDefault(tabId);
      case ShellTvZone.grid:
        if (memory.node != null && memory.node!.canRequestFocus) {
          return _request(memory.node!);
        }
        return _restoreDefault(tabId);
      case ShellTvZone.topBar:
        return ShellTvFocus.focusHomeSearch() || ShellTvFocus.focusHomeMenu();
      case ShellTvZone.chipStrip:
      case ShellTvZone.settings:
        if (memory.node != null && memory.node!.canRequestFocus) {
          return _request(memory.node!);
        }
        return _restoreDefault(tabId);
      case ShellTvZone.nav:
        return _restoreDefault(tabId);
    }
  }

  static bool _restoreDefault(String tabId) {
    _revealHeroForTab(tabId);
    final node =
        _tabDefaultFocus[tabId]?.call() ?? defaultFocusForTab?.call(tabId);
    if (node != null && node.canRequestFocus) {
      return _request(node);
    }
    return focusHero(revealFull: false, tabId: tabId);
  }

  static bool focusHero({bool revealFull = true, String? tabId}) {
    final tid = tabId ?? ShellTvFocus.currentNavTabId ?? '';
    if (revealFull) {
      _revealHeroForTab(tid);
    }
    final node = _tabDefaultFocus[tid]?.call();
    if (node != null && node.canRequestFocus) {
      return _request(node);
    }
    return ShellTvFocus.focusHomeHeroPlay();
  }

  // --- Row registry ---

  static void registerRow(ShellTvRowHandle handle) {
    final list = _rowsByTab.putIfAbsent(handle.tabId, () => []);
    final existing = _rowHandle(handle.tabId, handle.rowId);
    list.removeWhere((r) => r.rowId == handle.rowId);
    final h = ShellTvRowHandle(
      tabId: handle.tabId,
      rowId: handle.rowId,
      sortOrder: handle.sortOrder,
      itemCount: handle.itemCount,
      nodeAt: (index) =>
          itemNode(handle.tabId, handle.rowId, index) ?? handle.nodeAt(index),
      orientation: handle.orientation,
      isFirstRow: handle.isFirstRow,
      isLastRow: handle.isLastRow,
      onFocusUp: handle.onFocusUp,
      onFocusDown: handle.onFocusDown,
    )..lastFocusedIndex =
        existing?.lastFocusedIndex ?? handle.lastFocusedIndex;
    list.add(h);
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    _recomputeRowEdges(handle.tabId);
  }

  static void unregisterRow(String tabId, String rowId) {
    final list = _rowsByTab[tabId];
    if (list == null) return;
    list.removeWhere((r) => r.rowId == rowId);
    if (list.isEmpty) {
      _rowsByTab.remove(tabId);
    } else {
      _recomputeRowEdges(tabId);
    }
  }

  static void updateRowItemCount(String tabId, String rowId, int count) {
    final handle = _rowHandle(tabId, rowId);
    if (handle == null) return;
    handle.itemCount = count;
  }

  static void _recomputeRowEdges(String tabId) {
    final list = _rowsByTab[tabId];
    if (list == null || list.isEmpty) return;
    for (var i = 0; i < list.length; i++) {
      list[i].isFirstRow = i == 0;
      list[i].isLastRow = i == list.length - 1;
    }
  }

  static ShellTvRowHandle? rowHandle(String tabId, String rowId) =>
      _rowHandle(tabId, rowId);

  static ShellTvRowHandle? _rowHandle(String tabId, String rowId) {
    final list = _rowsByTab[tabId];
    if (list == null) return null;
    for (final row in list) {
      if (row.rowId == rowId) return row;
    }
    return null;
  }

  static ShellTvRowHandle? _nextRow(String tabId, int currentSortOrder) {
    final list = _rowsByTab[tabId];
    if (list == null) return null;
    ShellTvRowHandle? best;
    for (final row in list) {
      if (row.sortOrder <= currentSortOrder) continue;
      if (best == null || row.sortOrder < best.sortOrder) best = row;
    }
    return best;
  }

  static ShellTvRowHandle? _prevRow(String tabId, int currentSortOrder) {
    final list = _rowsByTab[tabId];
    if (list == null) return null;
    ShellTvRowHandle? best;
    for (final row in list) {
      if (row.sortOrder >= currentSortOrder) continue;
      if (best == null || row.sortOrder > best.sortOrder) best = row;
    }
    return best;
  }

  static bool focusRowItem(String tabId, String rowId, int index) {
    final handle = _rowHandle(tabId, rowId);
    if (handle == null || handle.itemCount <= 0) return false;
    final clamped = index.clamp(0, handle.itemCount - 1);
    final node = handle.nodeAt(clamped);
    if (node == null || !node.canRequestFocus) return false;
    handle.lastFocusedIndex = clamped;
    saveFocus(
      tabId,
      ShellTvFocusMemory(
        zone: ShellTvZone.row,
        rowId: rowId,
        itemIndex: clamped,
        node: node,
      ),
    );
    return _request(node);
  }

  /// Focus a row item, or the next registered row below when empty/unavailable.
  static bool focusRowItemOrNextBelow(
    String tabId,
    String rowId,
    int index,
  ) {
    if (focusRowItem(tabId, rowId, index)) return true;
    final handle = _rowHandle(tabId, rowId);
    if (handle == null) return false;
    final next = _nextRow(tabId, handle.sortOrder);
    if (next == null || next.itemCount <= 0) return false;
    final target = next.lastFocusedIndex.clamp(0, next.itemCount - 1);
    return focusRowItem(tabId, next.rowId, target);
  }

  /// Focus results row from chip strip — restores results history, not chip index.
  static bool focusFromChipStripDown({
    required String tabId,
    required String chipRowId,
    required String resultsRowId,
  }) {
    final results = _rowHandle(tabId, resultsRowId);
    if (results != null && results.itemCount > 0) {
      final idx = results.lastFocusedIndex.clamp(0, results.itemCount - 1);
      if (focusRowItem(tabId, resultsRowId, idx)) return true;
    }
    final chip = _rowHandle(tabId, chipRowId);
    if (chip == null) return false;
    return moveVerticalInTab(
      tabId: tabId,
      rowId: chipRowId,
      currentIndex: chip.lastFocusedIndex,
      down: true,
    );
  }

  /// Focus chip strip from results row — restores chip history, not card index.
  static bool focusFromResultsRowUp({
    required String tabId,
    required String chipRowId,
  }) {
    final chip = _rowHandle(tabId, chipRowId);
    if (chip == null || chip.itemCount <= 0) return false;
    final idx = chip.lastFocusedIndex.clamp(0, chip.itemCount - 1);
    return focusRowItem(tabId, chipRowId, idx);
  }

  static bool focusAdjacentInRow({
    required String tabId,
    required String rowId,
    required int currentIndex,
    required bool right,
  }) {
    final handle = _rowHandle(tabId, rowId);
    if (handle == null || handle.itemCount <= 0) return false;
    final next = right ? currentIndex + 1 : currentIndex - 1;
    if (next < 0 || next >= handle.itemCount) return false;
    return focusRowItem(tabId, rowId, next);
  }

  static bool moveInGrid({
    required String tabId,
    required String rowId,
    required int currentIndex,
    required int columns,
    required int rowDelta,
    required int colDelta,
  }) {
    final handle = _rowHandle(tabId, rowId);
    if (handle == null || handle.itemCount <= 0 || columns <= 0) {
      return false;
    }
    final row = currentIndex ~/ columns;
    final col = currentIndex % columns;
    final nextRow = row + rowDelta;
    final nextCol = col + colDelta;
    if (nextCol < 0 || nextCol >= columns) return false;
    final nextIndex = nextRow * columns + nextCol;
    if (nextIndex < 0 || nextIndex >= handle.itemCount) return false;
    return focusRowItem(tabId, rowId, nextIndex);
  }

  static void onRowItemFocused({
    required String tabId,
    required String rowId,
    required int index,
    required FocusNode node,
    ShellTvZone zone = ShellTvZone.row,
  }) {
    final handle = _rowHandle(tabId, rowId);
    if (handle != null) handle.lastFocusedIndex = index;
    saveFocus(
      tabId,
      ShellTvFocusMemory(
        zone: zone,
        rowId: rowId,
        itemIndex: index,
        node: node,
      ),
    );
  }

  static bool moveVerticalInTab({
    required String tabId,
    required String rowId,
    required int currentIndex,
    required bool down,
  }) {
    final handle = _rowHandle(tabId, rowId);
    if (handle == null) return false;

    if (!down) {
      if (handle.isFirstRow) {
        if (handle.onFocusUp != null) {
          handle.onFocusUp!();
          return true;
        }
        return focusHero(revealFull: true, tabId: tabId);
      }
      final prev = _prevRow(tabId, handle.sortOrder);
      if (prev == null) return false;
      if (prev.sortOrder < 0) {
        if (handle.onFocusUp != null) {
          handle.onFocusUp!();
          return true;
        }
        return focusHero(revealFull: true, tabId: tabId);
      }
      final target = prev.lastFocusedIndex.clamp(0, prev.itemCount - 1);
      return focusRowItem(tabId, prev.rowId, target);
    }

    if (handle.isLastRow) {
      return true; // trap — handled, no move
    }
    final next = _nextRow(tabId, handle.sortOrder);
    if (next == null) return true;
    final target = next.lastFocusedIndex.clamp(0, next.itemCount - 1);
    return focusRowItem(tabId, next.rowId, target);
  }

  static bool _request(FocusNode node) {
    if (!node.canRequestFocus) return false;
    node.requestFocus();
    return true;
  }

  static void clearTab(String tabId) {
    _tabMemory.remove(tabId);
    _rowsByTab.remove(tabId);
    _itemNodes.removeWhere((key, _) => key.startsWith('$tabId:'));
    unregisterTabDefaults(tabId);
  }

  // --- Per-item focus nodes (key = "tabId:rowId:index") ---

  static final Map<String, FocusNode> _itemNodes = {};

  static String _itemKey(String tabId, String rowId, int index) =>
      '$tabId:$rowId:$index';

  static void registerItemNode({
    required String tabId,
    required String rowId,
    required int index,
    required FocusNode node,
  }) {
    _itemNodes[_itemKey(tabId, rowId, index)] = node;
  }

  static void unregisterItemNode({
    required String tabId,
    required String rowId,
    required int index,
    required FocusNode node,
  }) {
    final key = _itemKey(tabId, rowId, index);
    if (_itemNodes[key] == node) _itemNodes.remove(key);
  }

  static FocusNode? itemNode(String tabId, String rowId, int index) =>
      _itemNodes[_itemKey(tabId, rowId, index)];
}

/// Metadata attached to TV focusable widgets.
class ShellTvFocusMeta {
  const ShellTvFocusMeta({
    required this.tabId,
    required this.zone,
    this.rowId,
    this.itemIndex,
    this.gridColumns,
    this.onSave,
  });

  final String tabId;
  final ShellTvZone zone;
  final String? rowId;
  final int? itemIndex;
  final int? gridColumns;
  final void Function(FocusNode node)? onSave;

  bool _isHorizontalNavZone() =>
      zone == ShellTvZone.row ||
      zone == ShellTvZone.chipStrip ||
      zone == ShellTvZone.topBar;

  bool Function()? resolveDownEdge() {
    if (rowId == null || itemIndex == null) return null;
    if (zone == ShellTvZone.grid && gridColumns != null) {
      final tid = tabId;
      final rid = rowId!;
      final idx = itemIndex!;
      final cols = gridColumns!;
      return () => ShellTvFocusCoordinator.moveInGrid(
            tabId: tid,
            rowId: rid,
            currentIndex: idx,
            columns: cols,
            rowDelta: 1,
            colDelta: 0,
          );
    }
    if (!_isHorizontalNavZone()) return null;
    final tid = tabId;
    final rid = rowId!;
    final idx = itemIndex!;
    final handle = ShellTvFocusCoordinator.rowHandle(tid, rid);
    if (handle?.orientation == ShellTvRowOrientation.vertical) {
      return () {
        if (idx >= handle!.itemCount - 1) {
          return ShellTvFocusCoordinator.moveVerticalInTab(
            tabId: tid,
            rowId: rid,
            currentIndex: idx,
            down: true,
          );
        }
        return ShellTvFocusCoordinator.focusAdjacentInRow(
          tabId: tid,
          rowId: rid,
          currentIndex: idx,
          right: true,
        );
      };
    }
    return () => ShellTvFocusCoordinator.moveVerticalInTab(
          tabId: tid,
          rowId: rid,
          currentIndex: idx,
          down: true,
        );
  }

  bool Function()? resolveUpEdge() {
    if (rowId == null || itemIndex == null) return null;
    if (zone == ShellTvZone.grid && gridColumns != null) {
      final tid = tabId;
      final rid = rowId!;
      final idx = itemIndex!;
      final cols = gridColumns!;
      return () => ShellTvFocusCoordinator.moveInGrid(
            tabId: tid,
            rowId: rid,
            currentIndex: idx,
            columns: cols,
            rowDelta: -1,
            colDelta: 0,
          );
    }
    if (!_isHorizontalNavZone()) return null;
    final tid = tabId;
    final rid = rowId!;
    final idx = itemIndex!;
    final handle = ShellTvFocusCoordinator.rowHandle(tid, rid);
    if (handle?.orientation == ShellTvRowOrientation.vertical) {
      return () {
        if (idx <= 0) {
          return ShellTvFocusCoordinator.moveVerticalInTab(
            tabId: tid,
            rowId: rid,
            currentIndex: idx,
            down: false,
          );
        }
        return ShellTvFocusCoordinator.focusAdjacentInRow(
          tabId: tid,
          rowId: rid,
          currentIndex: idx,
          right: false,
        );
      };
    }
    return () => ShellTvFocusCoordinator.moveVerticalInTab(
          tabId: tid,
          rowId: rid,
          currentIndex: idx,
          down: false,
        );
  }

  bool Function()? resolveLeftEdge() {
    if (rowId == null || itemIndex == null) return null;
    if (zone == ShellTvZone.grid && gridColumns != null) {
      final tid = tabId;
      final rid = rowId!;
      final idx = itemIndex!;
      final cols = gridColumns!;
      return () {
        if (idx % cols <= 0) return true;
        return ShellTvFocusCoordinator.moveInGrid(
          tabId: tid,
          rowId: rid,
          currentIndex: idx,
          columns: cols,
          rowDelta: 0,
          colDelta: -1,
        );
      };
    }
    if (!_isHorizontalNavZone()) return null;
    final tid = tabId;
    final rid = rowId!;
    final idx = itemIndex!;
    final handle = ShellTvFocusCoordinator.rowHandle(tid, rid);
    if (handle?.orientation == ShellTvRowOrientation.vertical) {
      return () => true;
    }
    return () {
      if (idx <= 0) return true;
      return ShellTvFocusCoordinator.focusAdjacentInRow(
        tabId: tid,
        rowId: rid,
        currentIndex: idx,
        right: false,
      );
    };
  }

  bool Function()? resolveRightEdge() {
    if (rowId == null || itemIndex == null) return null;
    if (zone == ShellTvZone.grid && gridColumns != null) {
      final tid = tabId;
      final rid = rowId!;
      final idx = itemIndex!;
      final cols = gridColumns!;
      return () {
        if (idx % cols >= cols - 1) return true;
        return ShellTvFocusCoordinator.moveInGrid(
          tabId: tid,
          rowId: rid,
          currentIndex: idx,
          columns: cols,
          rowDelta: 0,
          colDelta: 1,
        );
      };
    }
    if (!_isHorizontalNavZone()) return null;
    final tid = tabId;
    final rid = rowId!;
    final idx = itemIndex!;
    final handle = ShellTvFocusCoordinator.rowHandle(tid, rid);
    if (handle?.orientation == ShellTvRowOrientation.vertical) {
      return () => true;
    }
    return () {
      ShellTvFocusCoordinator.focusAdjacentInRow(
        tabId: tid,
        rowId: rid,
        currentIndex: idx,
        right: true,
      );
      return true;
    };
  }

  void notifyFocused(FocusNode node) {
    onSave?.call(node);
    if ((zone == ShellTvZone.row ||
            zone == ShellTvZone.chipStrip ||
            zone == ShellTvZone.grid) &&
        rowId != null &&
        itemIndex != null) {
      ShellTvFocusCoordinator.onRowItemFocused(
        tabId: tabId,
        rowId: rowId!,
        index: itemIndex!,
        node: node,
        zone: zone,
      );
    }
    switch (zone) {
      case ShellTvZone.hero:
        ShellTvFocusCoordinator.revealHeroForTab(tabId);
        ShellTvFocusCoordinator.saveFocus(
          tabId,
          ShellTvFocusMemory(zone: ShellTvZone.hero, node: node),
        );
      case ShellTvZone.topBar:
        ShellTvFocusCoordinator.saveFocus(
          tabId,
          ShellTvFocusMemory(zone: ShellTvZone.topBar, node: node),
        );
      case ShellTvZone.chipStrip:
        if (rowId == null) {
          ShellTvFocusCoordinator.saveFocus(
            tabId,
            ShellTvFocusMemory(zone: zone, node: node),
          );
        }
      case ShellTvZone.grid:
      case ShellTvZone.settings:
        ShellTvFocusCoordinator.saveFocus(
          tabId,
          ShellTvFocusMemory(zone: zone, node: node),
        );
      case ShellTvZone.row:
      case ShellTvZone.nav:
        break;
    }
  }
}

/// Whether [event] is a TV activate key (Select / OK).
bool shellTvIsActivateKey(KeyEvent event) {
  if (event is! KeyDownEvent) return false;
  final key = event.logicalKey;
  return key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.space ||
      key == LogicalKeyboardKey.numpadEnter;
}

/// Scroll visibility mode for TV focus.
enum ShellTvEnsureVisibleMode { off, row, item }
