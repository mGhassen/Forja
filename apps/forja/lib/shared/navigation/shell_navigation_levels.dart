import 'package:flutter/material.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:forja/shell/routing/shell_overlay_navigator.dart';
import 'package:forja/shared/foundation/services/nav/plugin_nav.dart';
import 'package:forja/shared/shell/tv/shell_tv_focus.dart';

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
/// Full metadata: [navDestinations] in `shell/nav/nav_config.dart`.
abstract final class ShellNavPages {
  /// TV in-scope shell tab IDs — host core + pack-contributed hubs that are
  /// currently registered. Do not hardcode pack tab ids.
  static List<String> get tvInScope => [
        'iptv',
        'settings',
        ...PluginNavRegistry.destinations.keys,
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
    if (rootNav == null) return;
    // Player PopScope uses canPop:false so [canPop] is false, but maybePop
    // still invokes onPopInvoked → [_exitPlayer] / LAN close.
    if (rootNav.canPop() || ShellBus.playerSurfaceActive.value) {
      rootNav.maybePop();
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
    // Player PopScope uses canPop:false so [rootRouteCanPop] is often false
    // while the surface is up — still treat as player so Back exits via maybePop.
    if (rootRouteCanPop() || ShellBus.playerSurfaceActive.value) {
      return ShellNavLevel.player;
    }
    if (shellOverlayCanPop()) return ShellNavLevel.detail;
    if (tabStackCanPop()) return ShellNavLevel.tabStack;
    if (ShellTvFocus.anyNavFocused || ShellTvFocus.primaryFocusIsNav) {
      return ShellNavLevel.menu;
    }
    return ShellNavLevel.page;
  }
}
