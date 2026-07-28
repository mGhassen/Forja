import 'dart:io' show Platform;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:forja/shared/navigation/navigation_back_handler.dart';
import 'package:forja/shared/navigation/shell_navigation_levels.dart';
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
class BackNavigationScope extends StatefulWidget {
  const BackNavigationScope({super.key, required this.child});

  final Widget child;

  @override
  State<BackNavigationScope> createState() => _BackNavigationScopeState();
}

class _BackNavigationScopeState extends State<BackNavigationScope>
    with WidgetsBindingObserver {
  late final VoidCallback _boundBack = _onBack;

  /// Global route - scrollables would otherwise eat [PointerPanZoom] before an
  /// ancestor [Listener] can treat a strong horizontal swipe as Back.
  double _panDx = 0;
  double _panDy = 0;
  bool _panning = false;

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

  void _onGlobalPointer(PointerEvent event) {
    if (event is PointerPanZoomStartEvent) {
      if (!_canNavigateBack) {
        _panning = false;
        return;
      }
      _panning = true;
      _panDx = 0;
      _panDy = 0;
      return;
    }
    if (event is PointerPanZoomUpdateEvent) {
      if (!_panning) return;
      _panDx += event.panDelta.dx;
      _panDy += event.panDelta.dy;
      return;
    }
    if (event is PointerPanZoomEndEvent) {
      if (!_panning) return;
      final dx = _panDx;
      final dy = _panDy;
      _panning = false;
      _panDx = 0;
      _panDy = 0;

      final horizontal = dx.abs() > dy.abs() * 1.35;
      final strong = dx.abs() >= 90;
      if (horizontal && strong && _canNavigateBack) {
        debugPrint(
          '[NavBack] trackpad pan dx=${dx.toStringAsFixed(0)} '
          'dy=${dy.toStringAsFixed(0)} → back',
        );
        _onBack();
      }
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

    return scope;
  }
}

class _BackIntent extends Intent {
  const _BackIntent();
}

class _EscapeIntent extends Intent {
  const _EscapeIntent();
}
