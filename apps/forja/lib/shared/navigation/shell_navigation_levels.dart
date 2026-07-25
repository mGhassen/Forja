import 'package:flutter/material.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';

/// Shell depth - back always travels up one level at a time.
///
/// ```
/// menu (nav rail)
///   └─ page (tab body: home, search, anime, iptv, …)
///        └─ tabStack (in-tab routes: iptv portal, m3u editor, …)
///             └─ detail (shell overlay: media details, overlay search, …)
///                  └─ player (root navigator: PlayerScreen, trailers, …)
/// ```
enum ShellNavLevel {
  menu,
  page,
  tabStack,
  detail,
  player,
}

/// TV in-scope shell tab IDs - level [ShellNavLevel.page].
/// Full metadata: [navDestinations] in `shell/nav_config.dart`.
abstract final class ShellNavPages {
  static const tvInScope = <String>[
    'home',
    'search',
    'anime',
    'asian_drama',
    'iptv',
    'live_matches',
    'mylist',
    'settings',
  ];
}

/// Resolves the active shell level and performs level-aware pops.
abstract final class ShellNavigationLevels {
  static bool rootRouteCanPop() {
    final ctx = shellOverlayNavigatorKey.currentContext;
    if (ctx == null) return false;
    final rootNav = Navigator.maybeOf(ctx, rootNavigator: true);
    return rootNav?.canPop() ?? false;
  }

  static void popRootRoute() {
    final ctx = shellOverlayNavigatorKey.currentContext;
    if (ctx == null) return;
    final rootNav = Navigator.maybeOf(ctx, rootNavigator: true);
    if (rootNav?.canPop() ?? false) {
      rootNav!.maybePop();
    }
  }

  static bool tabStackCanPop() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;

    final nav = Navigator.maybeOf(ctx);
    if (nav == null || !nav.canPop()) return false;

    final overlayNav = shellOverlayNavigatorKey.currentState;
    if (identical(nav, overlayNav)) return false;

    final rootNav = Navigator.maybeOf(ctx, rootNavigator: true);
    if (identical(nav, rootNav)) return false;

    return true;
  }

  static bool popTabStack() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;

    final nav = Navigator.maybeOf(ctx);
    if (nav == null || !nav.canPop()) return false;

    final overlayNav = shellOverlayNavigatorKey.currentState;
    if (identical(nav, overlayNav)) return false;

    final rootNav = Navigator.maybeOf(ctx, rootNavigator: true);
    if (identical(nav, rootNav)) return false;

    nav.maybePop();
    return true;
  }

  /// Deepest open level - used to decide which single step back takes.
  static ShellNavLevel resolveBackTarget() {
    if (rootRouteCanPop()) return ShellNavLevel.player;
    if (shellOverlayCanPop()) return ShellNavLevel.detail;
    if (tabStackCanPop()) return ShellNavLevel.tabStack;
    if (ShellTvFocus.anyNavFocused || ShellTvFocus.primaryFocusIsNav) {
      return ShellNavLevel.menu;
    }
    return ShellNavLevel.page;
  }
}
