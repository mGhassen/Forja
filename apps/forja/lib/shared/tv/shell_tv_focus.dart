import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_hold_accel.dart';

export 'package:forja/shared/tv/shell_tv_hold_accel.dart' show ShellTvHoldAccel;

/// D-pad navigation key - first press and OS key-repeat.
bool shellTvIsNavigationKey(KeyEvent event) =>
    event is KeyDownEvent || event is KeyRepeatEvent;

/// TV D-pad focus anchors shared across shell nav, home chrome, and catalog rows.
abstract final class ShellTvFocus {
  static String? currentNavTabId;

  static FocusNode? homeHeroPlay;
  static FocusNode? homeHeroGallery;
  static FocusNode? homeSearch;
  static FocusNode? homeMenu;
  static FocusNode? homeProviderRailFirst;
  static final Map<int, FocusNode> homeProviderRailById = {};

  static final Map<String, FocusNode> _navNodes = {};

  static void registerNav(String id, FocusNode node) {
    _navNodes[id] = node;
  }

  static void unregisterNav(String id, FocusNode node) {
    if (_navNodes[id] == node) _navNodes.remove(id);
  }

  /// Test-only — drop all rail FocusNode registrations between widget tests.
  @visibleForTesting
  static void clearNavRegistrationsForTest() => _navNodes.clear();

  static bool get anyNavFocused =>
      _navNodes.values.any((node) => node.hasFocus);

  static bool get primaryFocusIsNav {
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return false;
    for (final node in _navNodes.values) {
      if (identical(node, primary)) return true;
    }
    return false;
  }

  static bool focusCurrentNavTab() => focusNavTab(currentNavTabId ?? '');

  static bool focusNavTab(String id) {
    if (id.isEmpty) return false;
    final node = _navNodes[id];
    if (node == null || !node.canRequestFocus) return false;
    currentNavTabId = id;
    node.requestFocus();
    return true;
  }

  /// After overlay pop on desktop: land keyboard focus on the selected rail tab.
  static void scheduleFocusNavTab(String id, {int maxAttempts = 6}) {
    if (id.isEmpty) return;
    void attempt(int n) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (focusNavTab(id)) return;
        if (n < maxAttempts) attempt(n + 1);
      });
    }

    attempt(0);
  }

  static FocusNode? navNode(String id) => _navNodes[id];

  static bool focusHomeHeroPlay() {
    final node = homeHeroPlay;
    if (node == null || !node.canRequestFocus) return false;
    node.requestFocus();
    return true;
  }

  static bool focusHomeHeroGallery() {
    final node = homeHeroGallery;
    if (node == null || !node.canRequestFocus) return false;
    node.requestFocus();
    return true;
  }

  static bool focusHomeSearch() {
    final node = homeSearch;
    if (node == null || !node.canRequestFocus) return false;
    node.requestFocus();
    return true;
  }

  static bool focusHomeMenu() {
    final node = homeMenu;
    if (node == null || !node.canRequestFocus) return false;
    node.requestFocus();
    return true;
  }

  static bool focusHomeProviderRail() {
    final node = homeProviderRailFirst;
    if (node == null || !node.canRequestFocus) return false;
    node.requestFocus();
    return true;
  }

  /// Focus the rail tile for [providerId], or the first tile if null / missing.
  static bool focusHomeProviderById(int? providerId) {
    final node = providerId == null
        ? null
        : homeProviderRailById[providerId];
    final target = (node != null && node.canRequestFocus)
        ? node
        : homeProviderRailFirst;
    if (target == null || !target.canRequestFocus) return false;
    target.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = target.context;
      if (ctx == null || !ctx.mounted) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.4,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
      );
    });
    return true;
  }

  /// Snapshot the shell tab's D-pad memory before overlay chrome remounts.
  static void captureOverlayReturnFocus({String? tabId}) =>
      ShellTvFocusCoordinator.captureOverlayReturnFocus(tabId: tabId);

  /// Restore last catalog/hero focus after details/search overlay pops.
  static void restoreOverlayReturnFocus() =>
      ShellTvFocusCoordinator.restoreCapturedOverlayReturnFocus();

  static void discardOverlayReturnFocus() =>
      ShellTvFocusCoordinator.discardCapturedOverlayReturnFocus();

  /// After opening the rail (may need a rebuild), land on [providerId].
  static void scheduleFocusHomeProviderById(int? providerId) {
    void attempt(int n) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (focusHomeProviderById(providerId)) return;
        if (n < 2) attempt(n + 1);
      });
    }

    attempt(0);
  }

  /// Hub hero search (anime, asian drama, …) - one active tab at a time.
  static FocusNode? hubHeroSearch;

  static bool focusHubHeroSearch() {
    final node = hubHeroSearch;
    if (node == null || !node.canRequestFocus) return false;
    node.requestFocus();
    return true;
  }

  /// Handle TV UP before directional focus can land on a stray ancestor.
  static KeyEventResult onArrowUp(KeyEvent event, bool Function() onUp) {
    if (!shellTvIsNavigationKey(event)) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.ignored;
    }
    return onUp() ? KeyEventResult.handled : KeyEventResult.ignored;
  }
}

/// Swallow horizontal D-pad at a row edge so focus stays in the hero / chip strip.
KeyEventResult shellTrapTvFocusHorizontalEdge(
  FocusNode node,
  KeyEvent event, {
  bool trapRight = false,
  bool trapLeft = false,
}) {
  if (!shellTvIsNavigationKey(event)) return KeyEventResult.ignored;
  if (trapRight && event.logicalKey == LogicalKeyboardKey.arrowRight) {
    return KeyEventResult.handled;
  }
  if (trapLeft && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
    return KeyEventResult.handled;
  }
  return KeyEventResult.ignored;
}

/// Marks a pane where D-pad must not auto-wire Left → shell nav
/// (`listIndex: 0` / `navLeftAlways`). Use on settings detail and overlays;
/// exit with Back / explicit edges instead.
class ShellTvContainDpad extends InheritedWidget {
  const ShellTvContainDpad({super.key, required super.child});

  static bool activeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ShellTvContainDpad>() != null;

  @override
  bool updateShouldNotify(covariant ShellTvContainDpad oldWidget) => false;
}

/// Opt-in subtree where ↑/← / ↓/→ walk focus linearly (reading order).
///
/// **Not the TV default.** Prefer nearest-neighbor [FocusNode.focusInDirection]
/// (spatial 2D). Use this only for rare vertical lists that regress without it.
/// Overlay / settings hosts keep a [FocusScope] + [ShellTvContainDpad] without
/// this wrapper.
class ShellTvLinearFocusScope extends InheritedWidget {
  const ShellTvLinearFocusScope({super.key, required super.child});

  static bool activeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ShellTvLinearFocusScope>() != null;

  @override
  bool updateShouldNotify(covariant ShellTvLinearFocusScope oldWidget) => false;
}

/// Opt out of [ShellTvLinearFocusScope] for panels with an explicit D-pad graph
/// (e.g. episode list ↔ season / search).
class ShellTvDisableLinearFocus extends InheritedWidget {
  const ShellTvDisableLinearFocus({super.key, required super.child});

  static bool activeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ShellTvDisableLinearFocus>() !=
      null;

  @override
  bool updateShouldNotify(covariant ShellTvDisableLinearFocus oldWidget) =>
      false;
}

/// Optional edge handlers when linear traversal cannot move further.
///
/// Settings detail panes intentionally omit [onBackwardEdge] so ← stays in the
/// right pane; [TvHeroActions.pageBack] returns focus to the category rail.
class ShellTvLinearFocusEdges extends InheritedWidget {
  const ShellTvLinearFocusEdges({
    super.key,
    this.onBackwardEdge,
    this.onForwardEdge,
    required super.child,
  });

  final bool Function()? onBackwardEdge;
  final bool Function()? onForwardEdge;

  static ShellTvLinearFocusEdges? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ShellTvLinearFocusEdges>();

  @override
  bool updateShouldNotify(covariant ShellTvLinearFocusEdges oldWidget) =>
      onBackwardEdge != oldWidget.onBackwardEdge ||
      onForwardEdge != oldWidget.onForwardEdge;
}

/// D-pad inside opt-in [ShellTvLinearFocusScope] - reading order, no wrap.
///
/// ↑/← → previous, ↓/→ → next, with [TraversalEdgeBehavior.stop] so the first
/// item never jumps to the last (and last never wraps to first).
/// When traversal stops, optional [ShellTvLinearFocusEdges] may handle the edge.
/// Outside this scope, callers must use spatial [FocusNode.focusInDirection].
///
/// Vertical holds use [ShellTvHoldAccel.lastStep] (set by the caller via
/// [ShellTvHoldAccel.note]) so long ↑/↓ accelerates through Settings / menus.
KeyEventResult shellTvLinearMenuArrows({
  required BuildContext context,
  required KeyEvent event,
}) {
  if (!ShellTvLinearFocusScope.activeOf(context)) {
    return KeyEventResult.ignored;
  }
  if (ShellTvDisableLinearFocus.activeOf(context)) {
    return KeyEventResult.ignored;
  }
  final key = event.logicalKey;
  final backward = key == LogicalKeyboardKey.arrowUp ||
      key == LogicalKeyboardKey.arrowLeft;
  final forward = key == LogicalKeyboardKey.arrowDown ||
      key == LogicalKeyboardKey.arrowRight;
  if (!backward && !forward) return KeyEventResult.ignored;
  if (!shellTvIsNavigationKey(event)) return KeyEventResult.ignored;

  final vertical = key == LogicalKeyboardKey.arrowUp ||
      key == LogicalKeyboardKey.arrowDown;
  final steps = vertical ? ShellTvHoldAccel.lastStep : 1;

  final scope = FocusScope.of(context);
  final edges = ShellTvLinearFocusEdges.maybeOf(context);
  // Default closedLoop makes previousFocus on the first node land on the last.
  final edge = scope.traversalEdgeBehavior;
  scope.traversalEdgeBehavior = TraversalEdgeBehavior.stop;
  try {
    var movedAny = false;
    for (var i = 0; i < steps; i++) {
      final moved = backward ? scope.previousFocus() : scope.nextFocus();
      if (!moved) {
        if (!movedAny) {
          final edgeHandler =
              backward ? edges?.onBackwardEdge : edges?.onForwardEdge;
          if (edgeHandler != null) {
            return edgeHandler()
                ? KeyEventResult.handled
                : KeyEventResult.ignored;
          }
        }
        break;
      }
      movedAny = true;
    }
  } finally {
    scope.traversalEdgeBehavior = edge;
  }
  return KeyEventResult.handled;
}

/// Coordinator-first D-pad arrows for catalog rows - traps horizontal edges.
///
/// Call [ShellTvHoldAccel.note] before this when ↑/↓ should accelerate.
KeyEventResult shellTvHandleRowArrows({
  required KeyEvent event,
  ShellTvFocusMeta? tvMeta,
  VoidCallback? onLeftEdge,
  VoidCallback? onRightEdge,
  VoidCallback? onUpEdge,
  VoidCallback? onDownEdge,
}) {
  if (!shellTvIsNavigationKey(event)) return KeyEventResult.ignored;
  final key = event.logicalKey;
  final rowBound = tvMeta != null &&
      tvMeta.rowId != null &&
      (tvMeta.zone == ShellTvZone.row ||
          tvMeta.zone == ShellTvZone.chipStrip ||
          tvMeta.zone == ShellTvZone.topBar);
  final gridBound =
      tvMeta != null && tvMeta.zone == ShellTvZone.grid && tvMeta.rowId != null;

  if (key == LogicalKeyboardKey.arrowLeft) {
    if (onLeftEdge != null) {
      onLeftEdge();
      return KeyEventResult.handled;
    }
    final left = tvMeta?.resolveLeftEdge();
    if (left != null) {
      // False (unregistered neighbor) must not swallow — spatial / trap next.
      return left() ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    if (tvMeta?.zone == ShellTvZone.chipStrip || rowBound) {
      return KeyEventResult.handled;
    }
    if (gridBound) return KeyEventResult.handled;
    return KeyEventResult.ignored;
  }
  if (key == LogicalKeyboardKey.arrowUp) {
    if (onUpEdge != null) {
      onUpEdge();
      return KeyEventResult.handled;
    }
    final up = tvMeta?.resolveUpEdge();
    if (up != null) {
      // False (missing row handle / unmounted neighbor) must not swallow —
      // spatial focusInDirection still has a chance. Trap-at-edge returns true.
      return up() ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    if (rowBound || gridBound) return KeyEventResult.handled;
    return KeyEventResult.ignored;
  }
  if (key == LogicalKeyboardKey.arrowDown) {
    if (onDownEdge != null) {
      onDownEdge();
      return KeyEventResult.handled;
    }
    final down = tvMeta?.resolveDownEdge();
    if (down != null) {
      return down() ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    if (rowBound || gridBound) return KeyEventResult.handled;
    return KeyEventResult.ignored;
  }
  if (key == LogicalKeyboardKey.arrowRight) {
    if (onRightEdge != null) {
      onRightEdge();
      return KeyEventResult.handled;
    }
    final right = tvMeta?.resolveRightEdge();
    if (right != null) {
      return right() ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    if (tvMeta?.zone == ShellTvZone.chipStrip || rowBound) {
      return KeyEventResult.handled;
    }
    if (gridBound) return KeyEventResult.handled;
    return KeyEventResult.ignored;
  }
  return KeyEventResult.ignored;
}

/// TV catalog item - block Flutter geometry from moving focus across rows.
KeyEventResult shellTvTrapRowGeometry({
  required KeyEvent event,
  required bool tvFocus,
  ShellTvFocusMeta? tvMeta,
  bool trapHorizontal = false,
}) {
  if (!tvFocus || !shellTvIsNavigationKey(event)) return KeyEventResult.ignored;
  final key = event.logicalKey;
  final grid = tvMeta?.zone == ShellTvZone.grid;
  final rowBound = tvMeta?.rowId != null && !grid;
  final chip = tvMeta?.zone == ShellTvZone.chipStrip;

  if (trapHorizontal || rowBound || chip) {
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      return KeyEventResult.handled;
    }
  }
  if ((rowBound || grid) &&
      (key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.arrowDown)) {
    return KeyEventResult.handled;
  }
  return KeyEventResult.ignored;
}
