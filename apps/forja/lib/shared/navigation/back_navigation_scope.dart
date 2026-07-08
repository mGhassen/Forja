import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Mouse back button + Escape pop for screens without a visible back control.
class BackNavigationScope extends StatelessWidget {
  const BackNavigationScope({super.key, required this.child});

  final Widget child;

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
              Navigator.maybePop(context);
              return null;
            },
          ),
        },
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            if (event.buttons == kBackMouseButton) {
              Navigator.maybePop(context);
            }
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
