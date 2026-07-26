import 'package:flutter/foundation.dart';
import 'package:forja/shell/shell_bus.dart';

/// TV remote Back while a player surface is active:
/// 1. Menus/panels dismiss first ([dismissAnyPlayerChromeOverlay]).
/// 2. Visible player chrome hides ([tryHideChrome]) — stay in player.
/// 3. Otherwise first Back arms exit; second within [confirmWindow] exits.
abstract final class PlayerBackExitGate {
  static DateTime? _armedAt;
  static VoidCallback? _onFirstBack;
  static bool Function()? _tryHideChrome;
  static bool _listening = false;

  /// How long the second Back still counts as “confirm exit”.
  static const Duration confirmWindow = Duration(seconds: 2);

  static bool get isArmed => _armedAt != null;

  static void _ensureSurfaceListener() {
    if (_listening) return;
    _listening = true;
    ShellBus.playerSurfaceActive.addListener(() {
      if (!ShellBus.playerSurfaceActive.value) {
        clear();
        _onFirstBack = null;
        _tryHideChrome = null;
      }
    });
  }

  /// Optional: feedback when the first Back arms exit (chrome already hidden).
  static void setOnFirstBack(VoidCallback? callback) {
    _ensureSurfaceListener();
    _onFirstBack = callback;
  }

  /// When chrome is visible, hide it and return `true` (Back stays in player).
  static void setTryHideChrome(bool Function()? callback) {
    _ensureSurfaceListener();
    _tryHideChrome = callback;
  }

  /// Returns `true` when chrome was visible and is now hidden.
  static bool tryHideChrome() {
    _ensureSurfaceListener();
    if (!ShellBus.playerSurfaceActive.value) return false;
    final cb = _tryHideChrome;
    if (cb == null) return false;
    try {
      return cb();
    } catch (e, st) {
      debugPrint('[PlayerBackExitGate] tryHideChrome failed: $e\n$st');
      return false;
    }
  }

  static void clear() {
    _armedAt = null;
  }

  /// Test-only.
  static void resetForTest() {
    clear();
    _onFirstBack = null;
    _tryHideChrome = null;
  }

  /// Returns `true` when this Back should keep the player open (first press).
  /// Returns `false` when exit may proceed (second press, or gate disabled).
  static bool consumeFirstBackStay({required bool enabled}) {
    _ensureSurfaceListener();
    if (!enabled) return false;
    if (!ShellBus.playerSurfaceActive.value) return false;

    final now = DateTime.now();
    final armedAt = _armedAt;
    if (armedAt != null && now.difference(armedAt) < confirmWindow) {
      clear();
      return false;
    }

    _armedAt = now;
    try {
      _onFirstBack?.call();
    } catch (e, st) {
      debugPrint('[PlayerBackExitGate] onFirstBack failed: $e\n$st');
    }
    return true;
  }
}
