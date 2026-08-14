import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:forja/shared/navigation/shell_navigation_levels.dart';
import 'package:forja/shared/player/controls/player_back_exit_gate.dart';
import 'package:forja/shared/player/controls/player_chrome_overlays.dart';
import 'package:forja/shared/tv/media_details_tv_scope.dart';
import 'package:forja/shared/tv/shell_tv_app_exit.dart';
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

/// Central TV D-pad coordinator - nav isolation, row memory, tab restore.
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
  /// Optional in-page Back step before focusing the nav rail (e.g. IPTV
  /// channels → category). Return true when Back was consumed.
  static final Map<String, bool Function()> _tabPageBack = {};

  /// Details overlay Back control - first remote Back focuses it, second pops.
  static FocusNode? _detailBackFocus;
  static bool _detailBackExitArmed = false;

  /// Per-tab default focus and hero scroll - survives multi-tab mount order.
  static void registerTabDefaults(
    String tabId, {
    FocusNode? Function()? defaultFocus,
    VoidCallback? heroReveal,
    VoidCallback? enterFromNavFocus,
    bool Function()? restoreFocus,
    bool Function()? pageBack,
  }) {
    if (defaultFocus != null) _tabDefaultFocus[tabId] = defaultFocus;
    if (heroReveal != null) _tabHeroReveal[tabId] = heroReveal;
    if (enterFromNavFocus != null) _tabEnterFocus[tabId] = enterFromNavFocus;
    if (restoreFocus != null) _tabRestoreFocus[tabId] = restoreFocus;
    if (pageBack != null) _tabPageBack[tabId] = pageBack;
  }

  static void unregisterTabDefaults(String tabId) {
    _tabDefaultFocus.remove(tabId);
    _tabHeroReveal.remove(tabId);
    _tabEnterFocus.remove(tabId);
    _tabRestoreFocus.remove(tabId);
    _tabPageBack.remove(tabId);
  }

  /// Register the media-details Back chevron for TV remote Back.
  static void registerDetailBackFocus(FocusNode? node) {
    _detailBackFocus = node;
    _detailBackExitArmed = false;
  }

  static void unregisterDetailBackFocus(FocusNode? node) {
    if (identical(_detailBackFocus, node)) {
      _detailBackFocus = null;
      _detailBackExitArmed = false;
    }
  }

  /// First Back on details focuses the Back chevron; returns true when stayed.
  static bool _tryFocusDetailBack() {
    final back = _detailBackFocus;
    if (back == null || !back.canRequestFocus) return false;
    if (back.hasFocus || _detailBackExitArmed) {
      _detailBackExitArmed = false;
      return false;
    }
    _detailBackExitArmed = true;
    back.requestFocus();
    debugPrint('[NavBack] focused details back - stay on details');
    return true;
  }

  /// Nav Enter on a tab - e.g. search field browse focus (not last page memory).
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
  /// Back on the nav rail: first press arms exit, second within 2s quits.
  /// Remote Exit (Escape) is separate — [handleShellExitKey].
  /// Returns true when consumed.
  ///
  /// Set [tvBackPolicyEnabled] from [ShellScaffold] when TV input policy is
  /// active - same signal as shell nav rail / D-pad focus (not
  /// [ShellTokens.isAndroidTvDevice] alone).
  static bool tvBackPolicyEnabled = false;

  static DateTime? _lastBackHandledAt;
  static const Duration _backDebounceWindow = Duration(milliseconds: 400);

  /// HW + didPopRoute land a few ms apart. Shorter than [_backDebounceWindow]
  /// so a real second Back can confirm after a stay step.
  static const Duration _backTwinWindow = Duration(milliseconds: 80);

  /// True after a Back that only moved focus (player/details Back control) so
  /// the confirming Back is not swallowed by [_backDebounceWindow].
  static bool _backStepPending = false;

  /// Test-only - clears back debounce between widget tests.
  static void resetBackDebounceForTest() {
    _lastBackHandledAt = null;
    _backStepPending = false;
    _dismissTransientOverlay = null;
    PlayerBackExitGate.resetForTest();
    ShellTvAppExit.resetForTest();
  }

  /// Shell OverlayEntry menus (hero My List status). HardwareKeyboard steals
  /// goBack before Focus onKey — register so Back dismisses the menu first.
  static bool Function()? _dismissTransientOverlay;

  static void setTransientOverlayDismiss(bool Function()? dismiss) {
    _dismissTransientOverlay = dismiss;
  }

  static bool tryDismissTransientOverlay() {
    final cb = _dismissTransientOverlay;
    if (cb == null) return false;
    return cb();
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

  /// Level-aware back - see [ShellNavigationLevels].
  /// Always returns true when [tvBackPolicyEnabled] (never finishes via a
  /// single Back — nav needs a second press; see [ShellTvAppExit]).
  static bool handleShellBackKey() {
    // Player menus/panels are OverlayEntries (not routes). Dismiss them
    // before debounce / exit arming — otherwise exitReady skips debounce and
    // HW + didPopRoute on the same press closes the menu then pops the player
    // (IPTV Stream stats → catalog). Stamp so the twin delivery is swallowed.
    if (dismissAnyPlayerChromeOverlay()) {
      PlayerBackExitGate.exitReady = false;
      _backStepPending = false;
      ShellTvAppExit.clear();
      _lastBackHandledAt = DateTime.now();
      return true;
    }

    // In-player overlays (IPTV search ladder, …). Same twin stamp as chrome
    // OverlayEntries — HardwareKeyboard steals Focus onKey for goBack.
    if (PlayerBackExitGate.tryConsumePlayerOverlay()) {
      PlayerBackExitGate.exitReady = false;
      _backStepPending = false;
      ShellTvAppExit.clear();
      _lastBackHandledAt = DateTime.now();
      return true;
    }

    if (tryDismissTransientOverlay()) {
      PlayerBackExitGate.exitReady = false;
      _backStepPending = false;
      ShellTvAppExit.clear();
      _lastBackHandledAt = DateTime.now();
      return true;
    }

    // Confirming exit / pop must not be swallowed by debounce.
    // Same-press twins (HardwareKeyboard + didPopRoute) still land inside
    // [_backTwinWindow] even when a stay step set [_backStepPending].
    final lastBack = _lastBackHandledAt;
    if (lastBack != null &&
        DateTime.now().difference(lastBack) < _backTwinWindow) {
      return true;
    }
    if (!_backStepPending &&
        !PlayerBackExitGate.exitReady &&
        _consumeDuplicateBack()) {
      return true;
    }
    _backStepPending = false;

    // TV players: first Back hides chrome (or arms); second exits.
    if (tvBackPolicyEnabled && PlayerBackExitGate.tryFocusBackStay()) {
      _backStepPending = true;
      PlayerBackExitGate.exitReady = false;
      _lastBackHandledAt = DateTime.now();
      ShellTvAppExit.clear();
      debugPrint('[NavBack] player back consumed - stay in player');
      return true;
    }

    if (!tvBackPolicyEnabled) {
      return _handleLegacyBackKey();
    }

    final target = ShellNavigationLevels.resolveBackTarget();
    debugPrint('[NavBack] shell back target=$target');
    switch (target) {
      case ShellNavLevel.player:
        ShellTvAppExit.clear();
        ShellNavigationLevels.popRootRoute();
        return true;
      case ShellNavLevel.detail:
        ShellTvAppExit.clear();
        if (_tryFocusDetailBack()) {
          _backStepPending = true;
          return true;
        }
        maybePopShellOverlay();
        return true;
      case ShellNavLevel.tabStack:
        ShellTvAppExit.clear();
        if (ShellNavigationLevels.popTabStack()) return true;
        _focusActiveNavFromPage();
        return true;
      case ShellNavLevel.page:
        ShellTvAppExit.clear();
        final tabId = ShellTvFocus.currentNavTabId ?? '';
        final pageBack = _tabPageBack[tabId];
        if (pageBack != null && pageBack()) {
          _backStepPending = true;
          return true;
        }
        _focusActiveNavFromPage();
        return true;
      case ShellNavLevel.menu:
        // Double Back on the rail exits (first arms, second quits).
        // Do not set _backStepPending — Android delivers Back twice per press
        // (HardwareKeyboard + didPopRoute); shell debounce + minConfirmGap
        // must swallow the duplicate so we do not quit on the first press.
        ShellTvAppExit.armOrExit(message: 'Press Back again to exit');
        return true;
    }
  }

  /// Remote Exit (Escape on TV) — double-confirm quit from anywhere.
  /// Distinct from Back; does not navigate.
  static bool handleShellExitKey() {
    if (!tvBackPolicyEnabled) {
      return handleShellBackKey();
    }
    // Same double-delivery problem as Back — minConfirmGap absorbs it.
    ShellTvAppExit.armOrExit(message: 'Press Exit again to exit');
    return true;
  }

  static bool _handleLegacyBackKey() {
    if (shellOverlayCanPop()) {
      maybePopShellOverlay();
      return true;
    }

    if (_tryPopFocusedNavigator()) {
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
      _restorePageFromNav(ShellTvFocus.currentNavTabId ?? '');
      return true;
    }

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
    // Skip holes (tab still in order but FocusNode not registered yet after
    // async navbar rebuild) so ↑/↓ never appear to jump over menus.
    for (var i = idx + 1; i < _navOrder.length; i++) {
      final next = _navNodeForId(_navIdAt(i));
      if (next != null && next.canRequestFocus) {
        next.requestFocus();
        return true;
      }
    }
    return false;
  }

  static bool focusPrevNavItem() {
    final current = _focusedNavId() ?? ShellTvFocus.currentNavTabId;
    final idx = _navIndexForId(current);
    if (idx == null || idx <= 0) return false;
    for (var i = idx - 1; i >= 0; i--) {
      final prev = _navNodeForId(_navIdAt(i));
      if (prev != null && prev.canRequestFocus) {
        prev.requestFocus();
        return true;
      }
    }
    return false;
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

  /// Nav RIGHT - return to the active tab page without switching tabs.
  static bool _restorePageFromNav(String tabId) {
    ShellTvAppExit.clear();
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

  /// Restore page focus after the rail handles RIGHT.
  ///
  /// Snapshots tab memory **before** moving focus — an empty
  /// [FocusManager.primaryFocus.unfocus] gap lets Flutter autofocus hero
  /// Play, which overwrites memory via [ShellTvFocusMeta.notifyFocused].
  static void restoreTabFocusAfterNav(String tabId) {
    if (tabId.isEmpty) return;
    final snapshot = _tabMemory[tabId];

    void attempt() {
      if (snapshot != null && snapshot.zone != ShellTvZone.nav) {
        // Re-apply in case a mid-frame autofocus polluted live memory.
        saveFocus(tabId, snapshot);
        if (_restoreFromMemory(tabId, snapshot) && _pageHasFocus()) return;
        if (_tryRestoreLiveNode(snapshot) && _pageHasFocus()) return;
      }
      if (!restoreTabFocus(tabId)) {
        _restoreDefault(tabId);
      }
    }

    // Prefer a synchronous requestFocus so nav loses focus by transfer —
    // no empty unfocus gap for Play autofocus to steal.
    attempt();
    if (_pageHasFocus()) return;

    // Two post-frame passes - ExcludeFocus on the tab stack lifts in the same
    // frame as overlay pop / rail RIGHT; hero Play may not be focusable yet.
    void scheduleAttempt({required int remaining}) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        attempt();
        if (!_pageHasFocus() && remaining > 0) {
          scheduleAttempt(remaining: remaining - 1);
        }
      });
    }

    scheduleAttempt(remaining: 2);
  }

  static bool _pageHasFocus() {
    if (ShellTvFocus.anyNavFocused || ShellTvFocus.primaryFocusIsNav) {
      return false;
    }
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return false;
    // Empty FocusScope (shell overlay root / ModalScope) is not page focus -
    // treating it as success left Anime/Home stuck after nav RIGHT.
    if (primary is FocusScopeNode && primary.focusedChild == null) {
      return false;
    }
    final ctx = primary.context;
    return ctx != null && ctx.mounted;
  }

  /// After the player route pops, details can land with an empty FocusScope
  /// (loading-overlay strip + watch-history rebuild race). Reclaim hero
  /// Play/Resume only when the page has no usable focus — never steal a
  /// successful restore.
  static void claimHeroPlayAfterPlayerExit(
    FocusNode play, {
    required bool Function() isMounted,
    int frameRetries = 4,
  }) {
    if (!tvBackPolicyEnabled) return;

    void attempt({required int remaining}) {
      if (!isMounted()) return;
      if (_pageHasFocus()) return;
      if (play.context != null && play.canRequestFocus) {
        play.requestFocus();
      }
      if (_pageHasFocus() || remaining <= 0) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        attempt(remaining: remaining - 1);
      });
    }

    attempt(remaining: frameRetries);
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
        if (_tryRestoreLiveNode(memory)) return true;
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
        // Prefer the remembered node (Search field/close). Never steal to Home
        // chrome when restoring a non-home tab.
        if (_tryRestoreLiveNode(memory)) return true;
        if (tabId == 'home') {
          return ShellTvFocus.focusHomeSearch() || ShellTvFocus.focusHomeMenu();
        }
        return _restoreDefault(tabId);
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

  /// Clears remembered D-pad index for a row (next restore lands on [index]).
  static void setRowLastFocusedIndex(
    String tabId,
    String rowId,
    int index,
  ) {
    final handle = _rowHandle(tabId, rowId);
    if (handle == null) return;
    handle.lastFocusedIndex =
        handle.itemCount <= 0 ? 0 : index.clamp(0, handle.itemCount - 1);
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
    // Prefer requested index, then 0 - lazy ListViews often lack off-screen nodes.
    for (final candidate in {clamped, 0}) {
      if (candidate < 0 || candidate >= handle.itemCount) continue;
      final node = handle.nodeAt(candidate);
      if (node == null || !node.canRequestFocus) continue;
      handle.lastFocusedIndex = candidate;
      saveFocus(
        tabId,
        ShellTvFocusMemory(
          zone: ShellTvZone.row,
          rowId: rowId,
          itemIndex: candidate,
          node: node,
        ),
      );
      if (_request(node)) return true;
    }
    return false;
  }

  /// Like [focusRowItem] but never falls back to index 0.
  /// Use when scrolling to a specific tile (e.g. return from IPTV player).
  static bool focusRowItemExact(String tabId, String rowId, int index) {
    final handle = _rowHandle(tabId, rowId);
    if (handle == null || handle.itemCount <= 0) return false;
    if (index < 0 || index >= handle.itemCount) return false;
    final node = handle.nodeAt(index);
    if (node == null || !node.canRequestFocus) return false;
    handle.lastFocusedIndex = index;
    saveFocus(
      tabId,
      ShellTvFocusMemory(
        zone: ShellTvZone.row,
        rowId: rowId,
        itemIndex: index,
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

  /// Focus results row from chip strip - restores results history, not chip index.
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

  /// Focus chip strip from results row - restores chip history, not card index.
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
    int step = 1,
  }) {
    final handle = _rowHandle(tabId, rowId);
    if (handle == null || handle.itemCount <= 0) return false;
    final stride = step < 1 ? 1 : step;
    final delta = (right ? 1 : -1) * stride;
    final target = (currentIndex + delta).clamp(0, handle.itemCount - 1);
    if (target == currentIndex) return false;
    final dir = right ? 1 : -1;
    // Prefer the accelerated target; walk back toward current if unmounted.
    for (var i = target; i != currentIndex; i -= dir) {
      if (focusRowItemExact(tabId, rowId, i)) return true;
    }
    // Step-1 fallback: keep walking past the neighbor (sparse registration).
    if (stride <= 1) {
      var next = target + dir;
      while (next >= 0 && next < handle.itemCount) {
        if (focusRowItemExact(tabId, rowId, next)) return true;
        next += dir;
      }
    }
    return false;
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
    var nextRow = row + rowDelta;
    final nextCol = col + colDelta;
    if (nextCol < 0 || nextCol >= columns) return false;
    final maxRow = (handle.itemCount - 1) ~/ columns;
    // Accel overshoot: clamp inside the grid (first-row exit uses onUpEdge).
    if (rowDelta.abs() > 1) {
      if (nextRow < 0) nextRow = 0;
      if (nextRow > maxRow) nextRow = maxRow;
    } else {
      if (nextRow < 0 || nextRow > maxRow) return false;
    }
    var nextIndex = nextRow * columns + nextCol;
    if (nextIndex < 0) return false;
    if (nextIndex >= handle.itemCount) {
      nextIndex = handle.itemCount - 1;
    }
    if (nextIndex == currentIndex) return false;
    if (focusRowItemExact(tabId, rowId, nextIndex)) return true;
    final step = nextIndex > currentIndex ? -1 : 1;
    for (var i = nextIndex; i != currentIndex; i += step) {
      if (focusRowItemExact(tabId, rowId, i)) return true;
    }
    return false;
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
      // Explicit onFocusUp (e.g. Featured/Popular → Play) skips intermediate rows.
      if (handle.onFocusUp != null) {
        handle.onFocusUp!();
        return true;
      }
      if (handle.isFirstRow) {
        return focusHero(revealFull: true, tabId: tabId);
      }
      // Walk upward past rows whose items are not built / not focusable yet.
      var cursor = handle.sortOrder;
      while (true) {
        final prev = _prevRow(tabId, cursor);
        if (prev == null) {
          return focusHero(revealFull: true, tabId: tabId);
        }
        if (prev.sortOrder < 0) {
          final target =
              prev.lastFocusedIndex.clamp(0, prev.itemCount - 1);
          if (focusRowItem(tabId, prev.rowId, target)) return true;
          return focusHero(revealFull: true, tabId: tabId);
        }
        final target =
            prev.lastFocusedIndex.clamp(0, prev.itemCount - 1);
        if (focusRowItem(tabId, prev.rowId, target)) return true;
        cursor = prev.sortOrder;
      }
    }

    if (handle.onFocusDown != null) {
      handle.onFocusDown!();
      return true;
    }

    // Walk downward past unbuilt / empty rows instead of swallowing the key.
    var cursor = handle.sortOrder;
    while (true) {
      final next = _nextRow(tabId, cursor);
      if (next == null) return true; // trap at last reachable row
      final target = next.lastFocusedIndex.clamp(0, next.itemCount - 1);
      if (focusRowItem(tabId, next.rowId, target)) return true;
      cursor = next.sortOrder;
    }
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
            rowDelta: ShellTvHoldAccel.lastStep,
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
        final step = ShellTvHoldAccel.lastStep;
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
          step: step,
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
            rowDelta: -ShellTvHoldAccel.lastStep,
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
        final step = ShellTvHoldAccel.lastStep;
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
          step: step,
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
      if (idx <= 0) {
        if (rid == MediaDetailsTv.heroRowId) {
          ShellTvFocusCoordinator.focusActiveNavTab();
        }
        return true;
      }
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
        // Last column of a full row, or last item of an incomplete last row.
        if (idx % cols >= cols - 1) return true;
        final handle = ShellTvFocusCoordinator.rowHandle(tid, rid);
        if (handle != null && idx >= handle.itemCount - 1) return true;
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

/// Whether [key] is a TV activate key (Select / OK / Enter / Space).
bool shellTvIsActivateLogicalKey(LogicalKeyboardKey key) {
  return key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.space ||
      key == LogicalKeyboardKey.numpadEnter;
}

/// Whether [event] is a TV activate key (Select / OK) on KeyDown.
bool shellTvIsActivateKey(KeyEvent event) {
  if (event is! KeyDownEvent) return false;
  return shellTvIsActivateLogicalKey(event.logicalKey);
}

/// Whether [event] is a TV activate key on KeyUp (for hold / double-tap).
bool shellTvIsActivateKeyUp(KeyEvent event) {
  if (event is! KeyUpEvent) return false;
  return shellTvIsActivateLogicalKey(event.logicalKey);
}

/// Scroll visibility mode for TV focus.
enum ShellTvEnsureVisibleMode { off, row, item }

/// Content-Y slack: page title + section label + first control still count as
/// "page top" so ↑ / land-focus snaps to [minScrollExtent] instead of
/// pinning the control flush and clipping chrome above it.
const double kShellTvListTopRevealSlackPx = 240;

ScrollableState? _nearestVerticalScrollable(BuildContext context) {
  var scrollable = Scrollable.maybeOf(context);
  while (scrollable != null) {
    final axis = axisDirectionToAxis(scrollable.position.axisDirection);
    if (axis == Axis.vertical) return scrollable;
    // maybeOf skips [scrollable] itself and walks to the parent.
    scrollable = Scrollable.maybeOf(scrollable.context);
  }
  return null;
}

/// TV vertical lists (settings, menus): keep the focused control on-screen.
///
/// When the control sits near the **start** of the scroll content, jump to
/// [ScrollPosition.minScrollExtent] so page titles / group labels above the
/// first focusable stay visible — and **do not** run keepVisible (AtEnd on a
/// tall first control scrolls down and clips everything above it). Mid-list
/// rows use keepVisible only.
void shellTvEnsureVisibleItem(
  BuildContext context, {
  double topRevealSlackPx = kShellTvListTopRevealSlackPx,
}) {
  final scrollable = _nearestVerticalScrollable(context);
  if (scrollable == null) return;
  final position = scrollable.position;
  if (!position.hasContentDimensions) return;

  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize || !box.attached) return;
  final viewportBox = scrollable.context.findRenderObject();
  if (viewportBox is! RenderBox || !viewportBox.hasSize) return;

  final topInViewport =
      box.localToGlobal(Offset.zero, ancestor: viewportBox).dy;
  final contentY = position.pixels + topInViewport;
  if (contentY <= topRevealSlackPx) {
    if (position.pixels > position.minScrollExtent + 0.5) {
      position.jumpTo(position.minScrollExtent);
    }
    return;
  }

  const zero = Duration.zero;
  Scrollable.ensureVisible(
    context,
    alignment: 0.0,
    duration: zero,
    alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
  );
  Scrollable.ensureVisible(
    context,
    alignment: 1.0,
    duration: zero,
    alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
  );
}

/// Lift a focused catalog card in the **vertical** page scroller.
///
/// Cards live inside a horizontal [ListView], so [Scrollable.maybeOf] / nearest
/// [RenderAbstractViewport] are the row — not the hub [CustomScrollView].
/// Use global coords vs the vertical viewport instead.
///
/// Only scrolls when the card would sit under the bottom inset (or above the
/// top) — mid-screen rows stay put.
void shellTvRevealCatalogRowFocus(
  BuildContext context, {
  double bottomInsetFraction = ShellTokens.tvCatalogRowFocusBottomInsetFraction,
  double extraBottomPx = 0,
  double extraTopPx = 0,
}) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize || !box.attached) return;

  final scrollable = _nearestVerticalScrollable(context);
  if (scrollable == null) return;
  final position = scrollable.position;
  final viewportBox = scrollable.context.findRenderObject();
  if (viewportBox is! RenderBox || !viewportBox.hasSize) return;

  final topLeft = box.localToGlobal(Offset.zero, ancestor: viewportBox);
  final viewportH = position.viewportDimension;
  final cardTop = topLeft.dy - extraTopPx;
  final cardBottom = topLeft.dy + box.size.height + extraBottomPx;
  final maxBottom = viewportH * (1.0 - bottomInsetFraction);

  var delta = 0.0;
  if (cardBottom > maxBottom) {
    delta = cardBottom - maxBottom;
  }
  if (cardTop - delta < 0) {
    delta = cardTop;
  }
  if (delta.abs() < 0.5) return;

  position.jumpTo(
    (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    ),
  );
}
