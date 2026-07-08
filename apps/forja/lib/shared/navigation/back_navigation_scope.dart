import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Mouse back and Escape for screens without a visible back control.
class BackNavigationScope extends StatelessWidget {
  const BackNavigationScope({super.key, required this.child});

  final Widget child;

  void _pop(BuildContext context) {
    if (!Navigator.canPop(context)) return;
    Navigator.maybePop(context);
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
