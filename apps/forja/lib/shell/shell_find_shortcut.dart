import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Desktop shell shortcut: Cmd+F (macOS) / Ctrl+F (Windows/Linux).
class ShellFindShortcutScope extends StatelessWidget {
  const ShellFindShortcutScope({
    super.key,
    required this.enabled,
    required this.onFind,
    required this.child,
  });

  final bool enabled;
  final VoidCallback onFind;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        if (event.logicalKey != LogicalKeyboardKey.keyF) {
          return KeyEventResult.ignored;
        }

        final keyboard = HardwareKeyboard.instance;
        if (!keyboard.isMetaPressed && !keyboard.isControlPressed) {
          return KeyEventResult.ignored;
        }

        onFind();
        return KeyEventResult.handled;
      },
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.keyF, meta: true):
              _ShellFindIntent(),
          SingleActivator(LogicalKeyboardKey.keyF, control: true):
              _ShellFindIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _ShellFindIntent: CallbackAction<_ShellFindIntent>(
              onInvoke: (_) {
                onFind();
                return null;
              },
            ),
          },
          child: child,
        ),
      ),
    );
  }
}

class _ShellFindIntent extends Intent {
  const _ShellFindIntent();
}
