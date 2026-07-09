import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';

/// Mouse back and Escape pop the top route (root navigator, then shell overlay).
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

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): _PopIntent(),
      },
      child: Actions(
        actions: {
          _PopIntent: CallbackAction<_PopIntent>(
            onInvoke: (_) {
              _pop(context);
              return null;
            },
          ),
        },
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            if (event.buttons == kBackMouseButton) _pop(context);
          },
          child: child,
        ),
      ),
    );
  }
}

class _PopIntent extends Intent {
  const _PopIntent();
}
