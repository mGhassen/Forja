import 'package:flutter/services.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';

/// Android TV / leanback remote Back + Exit (Escape) keys.
///
/// Back → in-app navigation ([ShellTvFocusCoordinator.handleShellBackKey]).
/// Exit → double-confirm quit ([ShellTvFocusCoordinator.handleShellExitKey]).
abstract final class ShellTvBackHandler {
  static bool _installed = false;

  static void install() {
    if (_installed) return;
    _installed = true;
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  static void uninstall() {
    if (!_installed) return;
    HardwareKeyboard.instance.removeHandler(_onKey);
    _installed = false;
  }

  static bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.goBack) {
      ShellTvFocusCoordinator.handleShellBackKey();
      return true;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (ShellTvFocusCoordinator.tvBackPolicyEnabled) {
        ShellTvFocusCoordinator.handleShellExitKey();
        return true;
      }
      ShellTvFocusCoordinator.handleShellBackKey();
      return true;
    }
    return false;
  }
}
