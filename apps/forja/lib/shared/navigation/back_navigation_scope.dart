import 'dart:io' show Platform;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:forja/shared/navigation/desktop_swipe_back_indicator.dart';
import 'package:forja/shared/navigation/desktop_trackpad_nav.dart';
import 'package:forja/shared/navigation/navigation_back_handler.dart';
import 'package:forja/shared/navigation/shell_navigation_levels.dart';
import 'package:forja/shared/player/controls/player_back_exit_gate.dart';
import 'package:forja/shared/player/controls/player_chrome_overlays.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';

/// Mouse back, Escape, macOS trackpad swipe-back, and Android system / remote
/// Back - same level-aware pops as the in-app back control.
///
/// On Android, Flutter finishes the [Activity] when every
/// [WidgetsBindingObserver.didPopRoute] returns false (see
/// [WidgetsBinding.handlePopRoute] → [SystemNavigator.pop]). The shell uses a
/// nested overlay [Navigator], so the root route often cannot pop even while
/// details/player are open - that used to quit to the leanback launcher.
/// This scope always consumes Android pop-route and keeps
/// [SystemNavigator.setFrameworkHandlesBack] true so Back never exits.
///
/// Desktop trackpad: progressive left-edge arrow (browser-style). Only arms
/// when the pan starts near the **left window edge** and not over a scroll
/// viewport — catalog rows, Sources/addon panels, and cards never commit Back.
/// Back commits only when the indicator is fully filled.
class BackNavigationScope extends StatefulWidget {
  const BackNavigationScope({super.key, required this.child});

  final Widget child;

  @override
  State<BackNavigationScope> createState() => _BackNavigationScopeState();
}

class _BackNavigationScopeState extends State<BackNavigationScope>
    with WidgetsBindingObserver {
  late final VoidCallback _boundBack = _onBack;

  double _panDx = 0;
  double _panDy = 0;
  bool _panning = false;
  bool _navSuppressed = false;
  double _navProgress = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NavigationBackHandler.bind(_boundBack);
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      GestureBinding.instance.pointerRouter.addGlobalRoute(_onGlobalPointer);
    }
    if (Platform.isAndroid) {
      // Root navigator often reports canHandlePop=false; without this Android
      // finishes the Activity on the next Back without calling into Dart.
      SystemNavigator.setFrameworkHandlesBack(true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(_onGlobalPointer);
    }
    NavigationBackHandler.unbind(_boundBack);
    super.dispose();
  }

  /// Android system Back / predictive-back → navigation channel `popRoute`.
  /// Returning true stops [WidgetsBinding.handlePopRoute] from calling
  /// [SystemNavigator.pop] (which destroys [MainActivity]).
  @override
  Future<bool> didPopRoute() async {
    if (!Platform.isAndroid) return false;
    debugPrint('[NavBack] didPopRoute → in-app back (block Activity finish)');
    if (mounted) _onBack();
    return true;
  }

  bool get _canNavigateBack {
    switch (ShellNavigationLevels.resolveBackTarget()) {
      case ShellNavLevel.player:
      case ShellNavLevel.detail:
      case ShellNavLevel.tabStack:
        return true;
      case ShellNavLevel.page:
      case ShellNavLevel.menu:
        return shellOverlayCanPop() || ShellNavigationLevels.rootRouteCanPop();
    }
  }

  void _setNavProgress(double value) {
    final next = value.clamp(0.0, 1.0);
    // Skip tiny mid-gesture noise; always apply clear / show transitions.
    if ((next - _navProgress).abs() < 0.008 &&
        next > 0 &&
        _navProgress > 0) {
      return;
    }
    if (!mounted) {
      _navProgress = next;
      return;
    }
    setState(() => _navProgress = next);
  }

  void _resetPan({bool commit = false}) {
    final progress = _navProgress;
    _panning = false;
    _navSuppressed = false;
    _panDx = 0;
    _panDy = 0;
    if (commit && progress >= 1.0 - 1e-6 && _canNavigateBack) {
      _setNavProgress(0);
      debugPrint('[NavBack] trackpad swipe-back committed');
      _onBack();
      return;
    }
    _setNavProgress(0);
  }

  void _onGlobalPointer(PointerEvent event) {
    if (event is PointerPanZoomStartEvent) {
      if (!_canNavigateBack) {
        _panning = false;
        _navSuppressed = true;
        return;
      }
      _panning = true;
      _panDx = 0;
      _panDy = 0;
      _navSuppressed = desktopSwipeBackBlocked(
        event.position,
        viewId: event.viewId,
      );
      if (_navSuppressed) {
        _setNavProgress(0);
      }
      return;
    }
    if (event is PointerPanZoomUpdateEvent) {
      if (!_panning) return;

      // Cursor can enter a chip row / Sources panel mid-gesture.
      if (!_navSuppressed &&
          desktopSwipeBackBlocked(event.position, viewId: event.viewId)) {
        _navSuppressed = true;
        _setNavProgress(0);
        return;
      }
      if (_navSuppressed) return;

      _panDx += event.panDelta.dx;
      _panDy += event.panDelta.dy;

      final dx = _panDx;
      final dy = _panDy;
      final moved = dx.abs() + dy.abs();
      if (moved < 12) return;

      // Vertical-dominant pan → cancel back gesture.
      if (dy.abs() > dx.abs() * 1.35) {
        _setNavProgress(0);
        return;
      }

      // Back only: finger moves right (positive dx).
      if (dx <= 0) {
        _setNavProgress(0);
        return;
      }

      _setNavProgress(dx / kDesktopSwipeBackCommitPx);
      return;
    }
    if (event is PointerPanZoomEndEvent) {
      if (!_panning) return;
      final commit = !_navSuppressed && _navProgress >= 1.0 - 1e-6;
      _resetPan(commit: commit);
    }
  }

  bool _popNavigatorOrOverlay(BuildContext context) {
    final rootNav = Navigator.maybeOf(context, rootNavigator: true);
    if (rootNav != null && rootNav.canPop()) {
      rootNav.maybePop();
      return true;
    }
    if (shellOverlayCanPop()) {
      maybePopShellOverlay();
      return true;
    }
    return false;
  }

  /// Desktop / phone: match UI back - player → detail → tab stack.
  /// Does not steal focus to the nav rail or exit the app (TV-only).
  bool _handleDesktopOrMobileBack() {
    // Overlay menus are not navigator routes - close them before popping.
    if (dismissAnyPlayerChromeOverlay()) return true;
    switch (ShellNavigationLevels.resolveBackTarget()) {
      case ShellNavLevel.player:
        ShellNavigationLevels.popRootRoute();
        return true;
      case ShellNavLevel.detail:
        maybePopShellOverlay();
        return true;
      case ShellNavLevel.tabStack:
        return ShellNavigationLevels.popTabStack();
      case ShellNavLevel.page:
      case ShellNavLevel.menu:
        return false;
    }
  }

  void _onBack() {
    if (!mounted) return;
    final context = this.context;

    if (ShellTvFocusCoordinator.tvBackPolicyEnabled) {
      ShellTvFocusCoordinator.handleShellBackKey();
      return;
    }
    if (_handleDesktopOrMobileBack()) {
      return;
    }
    if (_popNavigatorOrOverlay(context)) {
      return;
    }
    // Root of the app - stay put. Never SystemNavigator.pop() from Back.
  }

  void _onExit() {
    if (!mounted) return;
    if (ShellTvFocusCoordinator.tvBackPolicyEnabled) {
      ShellTvFocusCoordinator.handleShellExitKey();
      return;
    }
    // Escape while a player route is up: if the player HardwareKeyboard
    // handler already consumed this key, do nothing (otherwise one Escape
    // arms then Shortcuts pops). Otherwise run the arm ladder here.
    if (ShellBus.playerSurfaceActive.value) {
      if (PlayerBackExitGate.playerEscapeHandledThisPulse()) return;
      if (dismissAnyPlayerChromeOverlay()) {
        PlayerBackExitGate.markStay();
        return;
      }
      if (PlayerBackExitGate.tryFocusBackStay()) return;
      _onBack();
      return;
    }
    _onBack();
  }

  @override
  Widget build(BuildContext context) {
    Widget scope = Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.goBack): _BackIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _EscapeIntent(),
      },
      child: Actions(
        actions: {
          _BackIntent: CallbackAction<_BackIntent>(
            onInvoke: (_) {
              _onBack();
              return null;
            },
          ),
          _EscapeIntent: CallbackAction<_EscapeIntent>(
            onInvoke: (_) {
              _onExit();
              return null;
            },
          ),
        },
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            if ((event.buttons & kBackMouseButton) != 0) _onBack();
          },
          child: widget.child,
        ),
      ),
    );

    if (Platform.isAndroid) {
      // Absorb NavigationNotification so WidgetsApp cannot set
      // frameworkHandlesBack=false when the root route cannot pop.
      scope = NotificationListener<NavigationNotification>(
        onNotification: (_) {
          SystemNavigator.setFrameworkHandlesBack(true);
          return true;
        },
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            _onBack();
          },
          child: scope,
        ),
      );
    }

    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      scope = Stack(
        fit: StackFit.expand,
        children: [
          scope,
          if (_navProgress > 0)
            DesktopSwipeBackIndicator(progress: _navProgress),
        ],
      );
    }

    return scope;
  }
}

class _BackIntent extends Intent {
  const _BackIntent();
}

class _EscapeIntent extends Intent {
  const _EscapeIntent();
}
