import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:forja/shared/shell/forja_shell_keyboard_focus_scope.dart';
import 'package:forja/shared/shell/tv/shell_tv_coordinator.dart';

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

  bool _isFinePointer(PointerDeviceKind kind) {
    return kind == PointerDeviceKind.mouse ||
        kind == PointerDeviceKind.trackpad ||
        kind == PointerDeviceKind.stylus;
  }

  void _hideKeyboardChrome() {
    if (_chromeVisible.value) {
      _chromeVisible.value = false;
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!_isFinePointer(event.kind)) return;
    final wasKeyboard = _chromeVisible.value;
    _hideKeyboardChrome();
    if (wasKeyboard) {
      _releaseKeyboardFocus();
    }
    ShellTvFocusCoordinator.unfocusShellNav();
  }

  /// Mouse move (no click) — hide focus rings; keep FocusNode so Tab resumes.
  void _onPointerHover(PointerHoverEvent event) {
    if (!_isFinePointer(event.kind)) return;
    _hideKeyboardChrome();
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
        onPointerHover: _onPointerHover,
        child: widget.child,
      ),
    );
  }
}
