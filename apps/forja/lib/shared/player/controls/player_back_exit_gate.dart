import 'package:flutter/foundation.dart';
import 'package:forja/shell/shell_bus.dart';

/// TV remote Back while a player surface is active:
/// 1. Menus/panels dismiss first ([dismissAnyPlayerChromeOverlay]).
/// 2. First Back shows chrome and focuses the player Back control.
/// 3. Second Back (Back already focused) exits the player.
abstract final class PlayerBackExitGate {
  static bool Function()? _tryFocusBack;
  static bool _listening = false;

  /// True after a Back that focused the Back control — next Back may exit
  /// without being swallowed by the shell debounce window.
  static bool exitReady = false;

  static void _ensureSurfaceListener() {
    if (_listening) return;
    _listening = true;
    ShellBus.playerSurfaceActive.addListener(() {
      if (!ShellBus.playerSurfaceActive.value) {
        _tryFocusBack = null;
        exitReady = false;
      }
    });
  }

  /// When Back would leave: close guide/search, show chrome, focus Back.
  ///
  /// Return `true` to keep the player open.
  /// Return `false` when Back is already focused (or cannot focus) so exit
  /// may proceed.
  static void setTryFocusBack(bool Function()? callback) {
    _ensureSurfaceListener();
    _tryFocusBack = callback;
  }

  /// Returns `true` when this Back should keep the player open.
  static bool tryFocusBackStay() {
    _ensureSurfaceListener();
    if (!ShellBus.playerSurfaceActive.value) {
      exitReady = false;
      return false;
    }
    final cb = _tryFocusBack;
    if (cb == null) {
      exitReady = false;
      return false;
    }
    try {
      final stay = cb();
      exitReady = stay;
      return stay;
    } catch (e, st) {
      debugPrint('[PlayerBackExitGate] tryFocusBack failed: $e\n$st');
      exitReady = false;
      return false;
    }
  }

  /// Test-only.
  static void resetForTest() {
    _tryFocusBack = null;
    exitReady = false;
  }
}
