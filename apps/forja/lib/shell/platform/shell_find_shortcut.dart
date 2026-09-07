import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Desktop shell find shortcut.
///
/// - **Windows / Linux:** Ctrl+F via a global [HardwareKeyboard] handler (does not
///   depend on focus sitting under [Shortcuts]).
/// - **macOS:** ⌘F is owned by Edit → Find… in AppKit; AppDelegate rewires that
///   menu and notifies Flutter through [MacOsShellChannel]. The meta handler here
///   is only a fallback if the key ever reaches Flutter.
class ShellFindShortcutScope extends StatefulWidget {
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
  State<ShellFindShortcutScope> createState() => _ShellFindShortcutScopeState();
}

class _ShellFindShortcutScopeState extends State<ShellFindShortcutScope> {
  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      HardwareKeyboard.instance.addHandler(_onKeyEvent);
    }
  }

  @override
  void didUpdateWidget(covariant ShellFindShortcutScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled == widget.enabled) return;
    if (widget.enabled) {
      HardwareKeyboard.instance.addHandler(_onKeyEvent);
    } else {
      HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    super.dispose();
  }

  bool _onKeyEvent(KeyEvent event) {
    if (!widget.enabled) return false;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.keyF) return false;

    final keyboard = HardwareKeyboard.instance;
    // Windows / Linux: Control. macOS fallback: Meta (primary path is AppKit menu).
    if (!keyboard.isControlPressed && !keyboard.isMetaPressed) return false;

    widget.onFind();
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
