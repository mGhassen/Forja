import 'package:flutter/material.dart';

/// TV D-pad focus anchors shared across shell nav, home chrome, and catalog rows.
abstract final class ShellTvFocus {
  static String? currentNavTabId;

  static FocusNode? homeHeroPlay;
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

  static bool focusCurrentNavTab() {
    final id = currentNavTabId;
    if (id == null) return false;
    final node = _navNodes[id];
    if (node == null || !node.canRequestFocus) return false;
    node.requestFocus();
    return true;
  }

  static bool focusHomeHeroPlay() {
    final node = homeHeroPlay;
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
}
