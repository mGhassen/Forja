import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/design/src/forja_toast.dart';
import 'package:forja/shared/platform/platform_channel.dart';

/// Double-confirm quit for Android TV (nav Back or remote Exit).
enum ShellTvAppExitOutcome {
  /// First press — toast shown; press again within [confirmWindow] to quit.
  armed,

  /// Second press within the window — app exit started.
  exited,
}

/// TV-only: leave the leanback launcher and kill the process (cold next launch).
abstract final class ShellTvAppExit {
  /// How long the second Back / Exit still counts as confirm.
  static const Duration confirmWindow = Duration(seconds: 2);

  /// Ignore confirm presses that arrive with the same physical key (Back is
  /// delivered twice: [HardwareKeyboard] + Android [didPopRoute]).
  static const Duration minConfirmGap = Duration(milliseconds: 450);

  static DateTime? _armedAt;

  /// Test-only — replaces [PlatformChannel.exitAppCompletely].
  @visibleForTesting
  static Future<void> Function()? debugExitOverride;

  /// Test-only — wall clock for arm/confirm timing.
  @visibleForTesting
  static DateTime Function()? debugNow;

  static DateTime _now() => debugNow?.call() ?? DateTime.now();

  static bool get isArmed {
    final at = _armedAt;
    if (at == null) return false;
    return _now().difference(at) < confirmWindow;
  }

  static void clear() {
    _armedAt = null;
  }

  /// First call arms; second within [confirmWindow] (and after [minConfirmGap])
  /// exits.
  static ShellTvAppExitOutcome armOrExit({required String message}) {
    final now = _now();
    final at = _armedAt;
    if (at != null) {
      final elapsed = now.difference(at);
      if (elapsed < confirmWindow) {
        // Same Back often hits us twice in one frame — stay armed.
        if (elapsed < minConfirmGap) {
          debugPrint(
            '[TvExit] ignore confirm within ${elapsed.inMilliseconds}ms '
            '(min ${minConfirmGap.inMilliseconds}ms)',
          );
          return ShellTvAppExitOutcome.armed;
        }
        clear();
        unawaited(_performExit());
        return ShellTvAppExitOutcome.exited;
      }
    }
    _armedAt = now;
    // Avoid pending toast timers under widget tests that use [debugExitOverride].
    if (debugExitOverride == null) {
      ForjaToast.info(message, duration: confirmWindow);
    }
    debugPrint('[TvExit] armed — $message');
    return ShellTvAppExitOutcome.armed;
  }

  static Future<void> _performExit() async {
    debugPrint('[TvExit] exiting app (finish + kill process)');
    final override = debugExitOverride;
    if (override != null) {
      await override();
      return;
    }
    await PlatformChannel.exitAppCompletely();
  }

  /// Test-only.
  static void resetForTest() {
    clear();
    debugExitOverride = null;
    debugNow = null;
  }
}
