import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:forja/shared/design/src/shell_keyboard_focus_scope.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';

/// Tracks pointer vs keyboard on desktop — wraps the shell under [MaterialApp].
class ShellKeyboardFocusHost extends StatefulWidget {
  const ShellKeyboardFocusHost({super.key, required this.child});

  final Widget child;

  @override
  State<ShellKeyboardFocusHost> createState() => _ShellKeyboardFocusHostState();
}

class _ShellKeyboardFocusHostState extends State<ShellKeyboardFocusHost> {
  final ValueNotifier<bool> _chromeVisible = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _chromeVisible.dispose();
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!_isKeyboardNavigationKey(event.logicalKey)) return false;
    if (!_chromeVisible.value) {
      _chromeVisible.value = true;
    }
    return false;
  }

  static bool _isKeyboardNavigationKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.tab ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.escape;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.mouse &&
        event.kind != PointerDeviceKind.trackpad &&
        event.kind != PointerDeviceKind.stylus) {
      return;
    }
    final wasKeyboard = _chromeVisible.value;
    if (wasKeyboard) {
      _chromeVisible.value = false;
      _releaseKeyboardFocus();
    }
    ShellTvFocusCoordinator.unfocusShellNav();
  }

  void _releaseKeyboardFocus() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return;
    final ctx = focus.context;
    if (ctx != null &&
        ctx.findAncestorWidgetOfExactType<EditableText>() != null) {
      return;
    }
    focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return ShellKeyboardFocusScope(
      visibility: _chromeVisible,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        child: widget.child,
      ),
    );
  }
}
