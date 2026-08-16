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
    HardwareKeyboard.instance.removeHandler(_onEatActivateUp);
    _eatActivateUp = false;
    _installed = false;
  }

  static bool _eatActivateUp = false;

  /// Overlay/dialog handled Select on KeyDown (e.g. Open LAN). Eat the matching
  /// KeyUp so the nav rail Home item does not treat it as enter-page.
  ///
  /// Registers a one-shot handler last so it runs before older player/nav
  /// HardwareKeyboard handlers.
  static void eatNextActivateUp() {
    _eatActivateUp = true;
    HardwareKeyboard.instance.removeHandler(_onEatActivateUp);
    HardwareKeyboard.instance.addHandler(_onEatActivateUp);
  }

  static bool _onEatActivateUp(KeyEvent event) {
    if (!_eatActivateUp || !shellTvIsActivateKeyUp(event)) return false;
    _eatActivateUp = false;
    HardwareKeyboard.instance.removeHandler(_onEatActivateUp);
    return true;
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
