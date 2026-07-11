import 'dart:io' show Platform;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';

/// Mouse back, Escape, and Android system / remote Back — pop routes or shell TV back chain.
class BackNavigationScope extends StatelessWidget {
  const BackNavigationScope({super.key, required this.child});

  final Widget child;

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

  void _onBack(BuildContext context) {
    if (ShellTvFocusCoordinator.handleShellBackKey()) {
      return;
    }
    // TV shell: only double-back on nav rail may exit (handled in coordinator).
    if (ShellTvFocusCoordinator.tvBackPolicyEnabled) {
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
              _onBack(context);
              return null;
            },
          ),
        },
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            if (event.buttons == kBackMouseButton) _onBack(context);
          },
          child: child,
        ),
      ),
    );

    if (Platform.isAndroid) {
      scope = PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _onBack(context);
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
