import 'package:flutter/foundation.dart';
import 'package:forja/shell/shell_bus.dart';

/// TV remote Back: first press stays in the player; second within [confirmWindow]
/// exits. Menus/panels still close on the first Back via chrome dismiss.
abstract final class PlayerBackExitGate {
  static DateTime? _armedAt;
  static VoidCallback? _onFirstBack;
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
      }
    });
  }

  /// Optional: show player chrome when the first Back arms exit.
  static void setOnFirstBack(VoidCallback? callback) {
    _ensureSurfaceListener();
    _onFirstBack = callback;
  }

  static void clear() {
    _armedAt = null;
  }

  /// Test-only.
  static void resetForTest() {
    clear();
    _onFirstBack = null;
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
