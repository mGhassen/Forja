import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shell/tv/shell_tv_hold_accel.dart';

export 'package:forja/shell/tv/shell_tv_hold_accel.dart' show ShellTvHoldAccel;

/// D-pad navigation key - first press and OS key-repeat.
bool shellTvIsNavigationKey(KeyEvent event) =>
    event is KeyDownEvent || event is KeyRepeatEvent;

/// TV D-pad focus anchors shared across shell nav, hub chrome, and catalog rows.
abstract final class ShellTvFocus {
  static String? currentNavTabId;

  static String? verticalFilterRailTabId;
  static FocusNode? verticalFilterRailFirst;
  static final Map<String, FocusNode> verticalFilterRailById = {};

  static final Map<String, FocusNode> _navNodes = {};

  /// In-app mini player root focus (chrome door target).
  static FocusNode? _miniRoot;

  /// Which chrome door last jumped into mini — restore target on leave.
  static InAppMiniChromeDoor? _miniDoor;

  static FocusNode? _topBarMiniDoor;
  static FocusNode? _heroLastMiniDoor;

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

  static bool focusVerticalFilterRail() {
    final node = verticalFilterRailFirst;
    if (node == null || !node.canRequestFocus) return false;
    node.requestFocus();
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

  static bool focusVerticalFilterById(String tabId, String? optionId) {
    final node = optionId == null
        ? null
        : verticalFilterRailById[optionId];
    final target = (node != null && node.canRequestFocus)
        ? node
        : verticalFilterRailFirst;
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

  static void scheduleFocusVerticalFilterById(String tabId, String? optionId) {
    void attempt(int n) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (focusVerticalFilterById(tabId, optionId)) return;
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

  // ── In-app mini player chrome doors ─────────────────────────────────────

  static bool get miniRegistered =>
      _miniRoot != null && _miniRoot!.canRequestFocus;

  static void registerMini(FocusNode root) {
    _miniRoot = root;
  }

  static void unregisterMini() {
    _miniRoot = null;
    _miniDoor = null;
  }

  static void registerTopBarMiniDoor(FocusNode? node) {
    _topBarMiniDoor = node;
  }

  static void registerHeroLastMiniDoor(FocusNode? node) {
    _heroLastMiniDoor = node;
  }

  /// Jump to mini from a chrome door. Records [door] for restore.
  static bool focusMini({InAppMiniChromeDoor door = InAppMiniChromeDoor.nav}) {
    final node = _miniRoot;
    if (node == null || !node.canRequestFocus) return false;
    _miniDoor = door;
    node.requestFocus();
    return true;
  }

  /// Leave mini focus → last chrome door (or current nav tab).
  static bool restoreFromMini() {
    final door = _miniDoor;
    _miniDoor = null;
    switch (door) {
      case InAppMiniChromeDoor.topBar:
        final n = _topBarMiniDoor;
        if (n != null && n.canRequestFocus) {
          n.requestFocus();
          return true;
        }
        break;
      case InAppMiniChromeDoor.heroLast:
        final n = _heroLastMiniDoor;
        if (n != null && n.canRequestFocus) {
          n.requestFocus();
          return true;
        }
        break;
      case InAppMiniChromeDoor.nav:
      case null:
        break;
    }
    return focusCurrentNavTab();
  }

  /// True when in-app mini is registered (demoted). Chrome edges call this.
  static bool tryFocusMiniFromTopBar() =>
      focusMini(door: InAppMiniChromeDoor.topBar);

  static bool tryFocusMiniFromNav() =>
      focusMini(door: InAppMiniChromeDoor.nav);

  static bool tryFocusMiniFromHeroLast() =>
      focusMini(door: InAppMiniChromeDoor.heroLast);
}

/// Which shell chrome control opened the in-app mini focus door.
enum InAppMiniChromeDoor { topBar, nav, heroLast }

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

/// Optional edge handlers for linear hosts / Settings pages.
///
/// Settings category page: [onBackwardEdge] runs on every ← (any control) →
/// category rail — same ladder as Addons [TvKitRow] column-0 /
/// [TvHeroActions] pageBack. Catalog hosts omit it (← stays previous in
/// reading order).
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

/// Arrow that points at the Settings category list.
///
/// Left to right: the list is on the left. Right to left: it is on the right.
bool _isTowardSettingsCategories(BuildContext context, LogicalKeyboardKey key) {
  final rtl = Directionality.of(context) == TextDirection.rtl;
  return key ==
      (rtl ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft);
}

/// Settings detail: the arrow toward the category list runs [onBackwardEdge].
///
/// Call **after** [shellTvHandleRowArrows] **and** spatial [FocusNode.focusInDirection]
/// so a left neighbor (Stremio Sources ↔ Live Sports chips, pack side actions)
/// wins before page-back. Explicit [onLeftEdge] / TvKitRow column-0 still win
/// first. Used when [ShellTvDisableLinearFocus] skips the linear menu path.
KeyEventResult shellTvSettingsBackwardEdge({
  required BuildContext context,
  required KeyEvent event,
}) {
  if (!shellTvIsNavigationKey(event)) return KeyEventResult.ignored;
  if (!_isTowardSettingsCategories(context, event.logicalKey)) {
    return KeyEventResult.ignored;
  }
  final handler = ShellTvLinearFocusEdges.maybeOf(context)?.onBackwardEdge;
  if (handler == null) return KeyEventResult.ignored;
  return handler() ? KeyEventResult.handled : KeyEventResult.ignored;
}

/// D-pad inside opt-in [ShellTvLinearFocusScope] - reading order, no wrap.
///
/// Default: ↑/← → previous, ↓/→ → next, with [TraversalEdgeBehavior.stop].
/// When [ShellTvLinearFocusEdges.onBackwardEdge] is set (Settings pages), ←
/// exits the page — **↑ never does** (failed ↑ traps in-page).
/// Outside this scope, callers must use spatial [FocusNode.focusInDirection].
///
/// Vertical holds use [ShellTvHoldAccel.lastStep] (set by the caller via
/// [ShellTvHoldAccel.note]) so long ↑/↓ accelerates through menus.
KeyEventResult shellTvLinearMenuArrows({
  required BuildContext context,
  required KeyEvent event,
}) {
  if (!ShellTvLinearFocusScope.activeOf(context)) {
    return KeyEventResult.ignored;
  }
  if (ShellTvDisableLinearFocus.activeOf(context)) {
    // 2D packs page still owes ← → category when Edges is set.
    return shellTvSettingsBackwardEdge(context: context, event: event);
  }
  final key = event.logicalKey;
  if (!shellTvIsNavigationKey(event)) return KeyEventResult.ignored;

  final edges = ShellTvLinearFocusEdges.maybeOf(context);
  // Settings page: ← → category (or close drill), not previous row.
  if (_isTowardSettingsCategories(context, key) &&
      edges?.onBackwardEdge != null) {
    return edges!.onBackwardEdge!()
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }
  if (key == LogicalKeyboardKey.arrowRight && edges?.onForwardEdge != null) {
    return edges!.onForwardEdge!()
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

  final backward = key == LogicalKeyboardKey.arrowUp ||
      key == LogicalKeyboardKey.arrowLeft;
  final forward = key == LogicalKeyboardKey.arrowDown ||
      key == LogicalKeyboardKey.arrowRight;
  if (!backward && !forward) return KeyEventResult.ignored;

  final vertical = key == LogicalKeyboardKey.arrowUp ||
      key == LogicalKeyboardKey.arrowDown;
  final steps = vertical ? ShellTvHoldAccel.lastStep : 1;

  final scope = FocusScope.of(context);
  // Default closedLoop makes previousFocus on the first node land on the last.
  final edge = scope.traversalEdgeBehavior;
  scope.traversalEdgeBehavior = TraversalEdgeBehavior.stop;
  var movedAny = false;
  try {
    for (var i = 0; i < steps; i++) {
      final moved = backward ? scope.previousFocus() : scope.nextFocus();
      if (!moved) {
        if (!movedAny) {
          // ↑/↓ at the list edge stay in-page. Only ←/→ may run edge exits.
          if (_isTowardSettingsCategories(context, key) &&
              edges?.onBackwardEdge != null) {
            return edges!.onBackwardEdge!()
                ? KeyEventResult.handled
                : KeyEventResult.ignored;
          }
          if (key == LogicalKeyboardKey.arrowRight &&
              edges?.onForwardEdge != null) {
            return edges!.onForwardEdge!()
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
  return movedAny ? KeyEventResult.handled : KeyEventResult.ignored;
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
  bool containDpad = false,
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
      ShellTvFocusCoordinator.beginKitEdgeAttempt();
      onLeftEdge();
      if (!ShellTvFocusCoordinator.takeKitEdgeMiss()) {
        return KeyEventResult.handled;
      }
      // kitFocusEdge miss — fall through to meta / spatial.
    }
    final left = tvMeta?.resolveLeftEdge(containDpad: containDpad);
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
      ShellTvFocusCoordinator.beginKitEdgeAttempt();
      onUpEdge();
      if (!ShellTvFocusCoordinator.takeKitEdgeMiss()) {
        return KeyEventResult.handled;
      }
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
      ShellTvFocusCoordinator.beginKitEdgeAttempt();
      onDownEdge();
      if (!ShellTvFocusCoordinator.takeKitEdgeMiss()) {
        return KeyEventResult.handled;
      }
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
      ShellTvFocusCoordinator.beginKitEdgeAttempt();
      onRightEdge();
      if (!ShellTvFocusCoordinator.takeKitEdgeMiss()) {
        return KeyEventResult.handled;
      }
      // kitFocusEdge miss (e.g. sources-kind unmounted) — fall through.
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

/// Spatial ←/→/↑/↓ for foundation [Button] / Material focus nodes.
///
/// App-root [DirectionalFocusAction] no-ops ←/→ so catalog rows own horizontal
/// traps. [FocusableControl] / [ForjaInteractive] drive [FocusNode.focusInDirection]
/// themselves; Material buttons do not — pass this as [Button.onKeyEvent].
KeyEventResult shellTvSpatialFocusArrows({
  required FocusNode node,
  required KeyEvent event,
}) {
  if (event is KeyUpEvent) {
    ShellTvHoldAccel.note(event);
    return KeyEventResult.ignored;
  }
  if (!shellTvIsNavigationKey(event)) return KeyEventResult.ignored;
  ShellTvHoldAccel.note(event);
  final key = event.logicalKey;
  TraversalDirection? direction;
  if (key == LogicalKeyboardKey.arrowLeft) {
    direction = TraversalDirection.left;
  } else if (key == LogicalKeyboardKey.arrowRight) {
    direction = TraversalDirection.right;
  } else if (key == LogicalKeyboardKey.arrowUp) {
    direction = TraversalDirection.up;
  } else if (key == LogicalKeyboardKey.arrowDown) {
    direction = TraversalDirection.down;
  }
  if (direction == null) return KeyEventResult.ignored;
  final vertical = direction == TraversalDirection.up ||
      direction == TraversalDirection.down;
  final steps = vertical ? ShellTvHoldAccel.lastStep : 1;
  var n = FocusManager.instance.primaryFocus ?? node;
  var moved = false;
  for (var i = 0; i < steps; i++) {
    if (!n.focusInDirection(direction)) break;
    moved = true;
    n = FocusManager.instance.primaryFocus ?? n;
  }
  return moved ? KeyEventResult.handled : KeyEventResult.ignored;
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
    // Trap ↑/↓ for all row-bound / grid items after coordinator edges.
    // Vertical rails used to fall through to spatial and leak into a sibling
    // panel (IPTV cats → channels). Jump-then-focus owns lazy mounts.
    return KeyEventResult.handled;
  }
  return KeyEventResult.ignored;
}
