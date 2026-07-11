import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';

/// Mouse back, Escape, and TV Back — pop routes or shell TV back chain.
class BackNavigationScope extends StatelessWidget {
  const BackNavigationScope({super.key, required this.child});

  final Widget child;

  void _pop(BuildContext context) {
    final rootNav = Navigator.maybeOf(context, rootNavigator: true);
    if (rootNav != null && rootNav.canPop()) {
      rootNav.maybePop();
      return;
    }
    maybePopShellOverlay();
  }

  void _onBack(BuildContext context) {
    if (ShellTvFocus.currentNavTabId != null &&
        ShellTvFocusCoordinator.handleShellBackKey()) {
      return;
    }
    _pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
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
  }
}

class _BackIntent extends Intent {
  const _BackIntent();
}
