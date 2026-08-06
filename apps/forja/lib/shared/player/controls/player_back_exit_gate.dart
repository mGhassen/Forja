import 'package:flutter/foundation.dart';
import 'package:forja/shell/shell_bus.dart';

/// TV remote Back while a player surface is active:
/// 1. Menus/panels dismiss first ([dismissAnyPlayerChromeOverlay]).
/// 2. In-player overlays (search ladder, …) via [tryConsumePlayerOverlay].
/// 3. First Back shows chrome and focuses the player Back control.
/// 4. Second Back (Back already focused) exits the player.
abstract final class PlayerBackExitGate {
  static bool Function()? _tryFocusBack;
  static bool Function()? _tryConsumePlayerOverlay;
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
        _tryConsumePlayerOverlay = null;
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

  /// Multi-step overlays that own Back before the exit ladder (e.g. IPTV
  /// channel search: results → field → close). Handled like chrome Overlay
  /// dismiss so HW + didPopRoute twins are stamped away.
  static void setTryConsumePlayerOverlay(bool Function()? callback) {
    _ensureSurfaceListener();
    _tryConsumePlayerOverlay = callback;
  }

  /// Returns `true` when this Back was consumed by an in-player overlay step.
  static bool tryConsumePlayerOverlay() {
    _ensureSurfaceListener();
    if (!ShellBus.playerSurfaceActive.value) return false;
    final cb = _tryConsumePlayerOverlay;
    if (cb == null) return false;
    try {
      return cb();
    } catch (e, st) {
      debugPrint('[PlayerBackExitGate] tryConsumePlayerOverlay failed: $e\n$st');
      return false;
    }
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
    _tryConsumePlayerOverlay = null;
    exitReady = false;
  }
}
