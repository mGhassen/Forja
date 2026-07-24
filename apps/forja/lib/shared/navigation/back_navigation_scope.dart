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
/// Back — same level-aware pops as the in-app back control.
class BackNavigationScope extends StatefulWidget {
  const BackNavigationScope({super.key, required this.child});

  final Widget child;

  @override
  State<BackNavigationScope> createState() => _BackNavigationScopeState();
}

class _BackNavigationScopeState extends State<BackNavigationScope> {
  late final VoidCallback _boundBack = _onBack;

  /// Trackpad pan fallback when macOS delivers pan/zoom instead of swipe.
  /// Only from the left edge so catalog row flicks do not navigate.
  static const double _edgePx = 96;
  static const double _panBackDx = 110;
  double _panDx = 0;
  double _panDy = 0;
  bool _panFromEdge = false;
  bool _panning = false;

  @override
  void initState() {
    super.initState();
    NavigationBackHandler.bind(_boundBack);
  }

  @override
  void dispose() {
    NavigationBackHandler.unbind(_boundBack);
    super.dispose();
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

  void _onPanZoomStart(PointerPanZoomStartEvent event) {
    if (!Platform.isMacOS || !_canNavigateBack) return;
    _panning = true;
    _panDx = 0;
    _panDy = 0;
    _panFromEdge = event.position.dx <= _edgePx;
  }

  void _onPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    if (!_panning || !_panFromEdge) return;
    _panDx += event.panDelta.dx;
    _panDy += event.panDelta.dy;
  }

  void _onPanZoomEnd(PointerPanZoomEndEvent event) {
    if (!_panning) return;
    final fromEdge = _panFromEdge;
    final dx = _panDx;
    final dy = _panDy;
    _panning = false;
    _panFromEdge = false;
    _panDx = 0;
    _panDy = 0;
    if (!fromEdge) return;
    final horizontal = dx.abs() > dy.abs() * 1.5;
    // Finger moves right → positive dx → back (same as iOS edge swipe).
    if (horizontal && dx >= _panBackDx) {
      _onBack();
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

  /// Desktop / phone: match UI back — player → detail → tab stack.
  /// Does not steal focus to the nav rail or exit the app (TV-only).
  bool _handleDesktopOrMobileBack() {
    switch (ShellNavigationLevels.resolveBackTarget()) {
      case ShellNavLevel.player:
        if (dismissAnyPlayerChromeOverlay()) return true;
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
    if (Platform.isAndroid) {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget scope = Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): _BackIntent(),
        SingleActivator(LogicalKeyboardKey.goBack): _BackIntent(),
      },
      child: Actions(
        actions: {
          _BackIntent: CallbackAction<_BackIntent>(
            onInvoke: (_) {
              _onBack();
              return null;
            },
          ),
        },
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            if ((event.buttons & kBackMouseButton) != 0) _onBack();
          },
          onPointerPanZoomStart: _onPanZoomStart,
          onPointerPanZoomUpdate: _onPanZoomUpdate,
          onPointerPanZoomEnd: _onPanZoomEnd,
          child: widget.child,
        ),
      ),
    );

    if (Platform.isAndroid) {
      scope = PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _onBack();
        },
        child: scope,
      );
    }

    return scope;
  }
}

class _BackIntent extends Intent {
  const _BackIntent();
}
