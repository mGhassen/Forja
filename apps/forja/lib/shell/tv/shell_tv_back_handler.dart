import 'package:flutter/services.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';

/// Android TV / leanback remote Back + Exit (Escape) keys.
///
/// Back → in-app navigation ([ShellTvFocusCoordinator.handleShellBackKey]).
/// Exit → while a player is open, same leave ladder as Back; otherwise
/// double-confirm quit ([ShellTvFocusCoordinator.handleShellExitKey]).
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
    final key = event.logicalKey;
    if (event is KeyUpEvent) {
      // Android also reports this press as didPopRoute after KeyUp —
      // the coordinator pairs that pop with this press and ignores it.
      if (key == LogicalKeyboardKey.goBack) {
        ShellTvFocusCoordinator.noteHardwareBackUp();
        return true;
      }
      return false;
    }
    if (event is! KeyDownEvent) return false;
    if (key == LogicalKeyboardKey.goBack) {
      ShellTvFocusCoordinator.noteHardwareBackDown();
      ShellTvFocusCoordinator.handleShellBackKey();
      return true;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (!ShellTvFocusCoordinator.tvBackPolicyEnabled) {
        // Desktop/mobile: [BackNavigationScope] Shortcuts own Escape → back nav.
        return false;
      }
      ShellTvFocusCoordinator.handleShellExitKey();
      return true;
    }
    return false;
  }
}
