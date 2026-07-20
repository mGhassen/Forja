import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:forja/shared/tv/shell_tv_coordinator.dart';

/// D-pad navigation key — first press and OS key-repeat.
bool shellTvIsNavigationKey(KeyEvent event) =>
    event is KeyDownEvent || event is KeyRepeatEvent;

/// TV D-pad focus anchors shared across shell nav, home chrome, and catalog rows.
abstract final class ShellTvFocus {
  static String? currentNavTabId;

  static FocusNode? homeHeroPlay;
  static FocusNode? homeHeroGallery;
  static FocusNode? homeSearch;
  static FocusNode? homeMenu;

  static final Map<String, FocusNode> _navNodes = {};

  static void registerNav(String id, FocusNode node) {
    _navNodes[id] = node;
  }

  static void unregisterNav(String id, FocusNode node) {
    if (_navNodes[id] == node) _navNodes.remove(id);
  }

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

  static bool focusCurrentNavTab() {
    final id = currentNavTabId;
    if (id == null) return false;
    final node = _navNodes[id];
    if (node == null || !node.canRequestFocus) return false;
    node.requestFocus();
    return true;
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

  /// Hub hero search (anime, asian drama, …) — one active tab at a time.
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

/// Marks a subtree where ↑/← / ↓/→ walk focus linearly (menus, dialogs).
///
/// Without this, [FocusScopeNode.focusInDirection] often fails inside overlay
/// menus and arrows leak to the player chrome underneath.
class ShellTvLinearFocusScope extends InheritedWidget {
  const ShellTvLinearFocusScope({super.key, required super.child});

  static bool activeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ShellTvLinearFocusScope>() != null;

  @override
  bool updateShouldNotify(covariant ShellTvLinearFocusScope oldWidget) => false;
}

/// Linear D-pad inside [ShellTvLinearFocusScope] — traps at first/last item.
KeyEventResult shellTvLinearMenuArrows({
  required BuildContext context,
  required KeyEvent event,
}) {
  if (!shellTvIsNavigationKey(event)) return KeyEventResult.ignored;
  if (!ShellTvLinearFocusScope.activeOf(context)) {
    return KeyEventResult.ignored;
  }
  final key = event.logicalKey;
  final scope = FocusScope.of(context);
  if (key == LogicalKeyboardKey.arrowUp ||
      key == LogicalKeyboardKey.arrowLeft) {
    scope.previousFocus();
    return KeyEventResult.handled;
  }
  if (key == LogicalKeyboardKey.arrowDown ||
      key == LogicalKeyboardKey.arrowRight) {
    scope.nextFocus();
    return KeyEventResult.handled;
  }
  return KeyEventResult.ignored;
}

/// Coordinator-first D-pad arrows for catalog rows — traps horizontal edges.
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
      left();
      return KeyEventResult.handled;
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
      up();
      return KeyEventResult.handled;
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
      down();
      return KeyEventResult.handled;
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
      right();
      return KeyEventResult.handled;
    }
    if (tvMeta?.zone == ShellTvZone.chipStrip || rowBound) {
      return KeyEventResult.handled;
    }
    if (gridBound) return KeyEventResult.handled;
    return KeyEventResult.ignored;
  }
  return KeyEventResult.ignored;
}

/// TV catalog item — block Flutter geometry from moving focus across rows.
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
