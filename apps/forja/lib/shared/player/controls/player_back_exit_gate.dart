import 'package:flutter/foundation.dart';
import 'package:forja/shell/shell_bus.dart';

/// TV remote Back while a player surface is active:
/// 1. Menus/panels dismiss first ([dismissAnyPlayerChromeOverlay]).
/// 2. In-player overlays (search ladder, …) via [tryConsumePlayerOverlay].
/// 3. Chrome visible → hide chrome (stay). Chrome hidden → first Back arms,
///    second Back exits. The Back icon (OK / tap) still exits immediately.
abstract final class PlayerBackExitGate {
  static bool Function()? _tryFocusBack;
  static bool Function()? _tryConsumePlayerOverlay;
  static bool _listening = false;

  /// True after a Back that is ready to exit the player — next Back may skip
  /// the shell debounce window. Stay steps (hide chrome) must leave this false
  /// so HW + didPopRoute twins do not pop the player on the same press.
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

  /// Hide chrome or arm the confirming Back. Return `true` to stay.
  /// Return `false` so the confirming Back may exit.
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
      // Stay must not set [exitReady] — that skips the HW + didPopRoute
      // debounce and the twin would exit on the same press.
      exitReady = false;
      return stay;
    } catch (e, st) {
      debugPrint('[PlayerBackExitGate] tryFocusBack failed: $e\n$st');
      exitReady = false;
      return false;
    }
  }

  /// Chrome up → hide. Chrome down + armed → allow exit. Else arm.
  ///
  /// Return `true` to keep the player open.
  static bool consumeChromeOrArmExit({
    required bool chromeVisible,
    required bool armed,
    required VoidCallback hideChrome,
    required void Function(bool armed) setArmed,
  }) {
    if (chromeVisible) {
      hideChrome();
      setArmed(true);
      return true;
    }
    if (armed) {
      setArmed(false);
      return false;
    }
    setArmed(true);
    return true;
  }

  /// Test-only.
  static void resetForTest() {
    _tryFocusBack = null;
    _tryConsumePlayerOverlay = null;
    exitReady = false;
  }
}
