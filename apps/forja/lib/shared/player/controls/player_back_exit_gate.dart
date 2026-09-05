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
  static VoidCallback? _forceExitPlayer;
  static bool _listening = false;
  static DateTime? _lastStayAt;
  static bool _exitCommitted = false;
  /// Desktop player HardwareKeyboard already consumed Escape this pulse —
  /// Shortcuts [_EscapeIntent] must not arm/exit again on the same key.
  static DateTime? _playerEscapeHandledAt;
  static const _escapeHandledPulse = Duration(milliseconds: 50);

  /// Match shell [_backDebounceWindow] — ATV HW + didPopRoute twins often
  /// exceed 80ms under MediaKit load; a short window lets hide+arm then exit
  /// on the same physical Back.
  static const _stayTwinWindow = Duration(milliseconds: 400);

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
        _forceExitPlayer = null;
        exitReady = false;
        _lastStayAt = null;
        _exitCommitted = false;
        _playerEscapeHandledAt = null;
      }
    });
  }

  /// Hide chrome or arm the confirming Back. Return `true` to stay.
  /// Return `false` so the confirming Back may exit.
  static void setTryFocusBack(bool Function()? callback) {
    _ensureSurfaceListener();
    _tryFocusBack = callback;
  }

  /// Desktop film player: mouse Back / trackpad leave immediately.
  static void setForceExitPlayer(VoidCallback? callback) {
    _ensureSurfaceListener();
    _forceExitPlayer = callback;
  }

  /// Returns `true` when a force-exit callback ran (player left).
  static bool tryForceExitPlayer() {
    _ensureSurfaceListener();
    final cb = _forceExitPlayer;
    if (cb == null) return false;
    try {
      cb();
      return true;
    } catch (e, st) {
      debugPrint('[PlayerBackExitGate] forceExitPlayer failed: $e\n$st');
      return false;
    }
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
      debugPrint(
        '[PlayerBackExitGate] tryConsumePlayerOverlay failed: $e\n$st',
      );
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
    if (_lastStayAt != null &&
        DateTime.now().difference(_lastStayAt!) < _stayTwinWindow) {
      return true;
    }
    if (_exitCommitted) return false;
    final cb = _tryFocusBack;
    if (cb == null) {
      exitReady = false;
      return false;
    }
    try {
      final stay = cb();
      exitReady = false;
      if (stay) {
        _lastStayAt = DateTime.now();
        return true;
      }
      _exitCommitted = true;
      return false;
    } catch (e, st) {
      debugPrint('[PlayerBackExitGate] tryFocusBack failed: $e\n$st');
      exitReady = false;
      return false;
    }
  }

  /// Overlay / dialog Back was consumed — HW + PopScope twins must stay.
  static void markStay() {
    _lastStayAt = DateTime.now();
    exitReady = false;
    _exitCommitted = false;
  }

  /// True when a stay step stamped within this key pulse (~50ms).
  /// Used so DismissIntent arm + PopScope maybePop on the same Escape
  /// cannot arm then leave. Intentional second Escape is later.
  static bool wasStayThisKeyPulse() {
    if (_lastStayAt == null) return false;
    return DateTime.now().difference(_lastStayAt!) < _escapeHandledPulse;
  }

  /// True when [markStay] / a stay step ran within the TV twin window.
  static bool wasRecentStay() {
    if (_lastStayAt == null) return false;
    return DateTime.now().difference(_lastStayAt!) < _stayTwinWindow;
  }

  /// Desktop film player handled Escape in [HardwareKeyboard] — Shortcuts
  /// must ignore the same key (otherwise arm + pop happen on one press).
  static void notePlayerEscapeHandled() {
    _playerEscapeHandledAt = DateTime.now();
  }

  /// True when [notePlayerEscapeHandled] ran in this key pulse.
  static bool playerEscapeHandledThisPulse() {
    final t = _playerEscapeHandledAt;
    if (t == null) return false;
    return DateTime.now().difference(t) < _escapeHandledPulse;
  }

  /// Chrome up → hide and arm (next intentional Back exits). Chrome down +
  /// armed → allow exit. Chrome down + not armed → arm only.
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
    _forceExitPlayer = null;
    exitReady = false;
    _lastStayAt = null;
    _exitCommitted = false;
    _playerEscapeHandledAt = null;
  }
}
