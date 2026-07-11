import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';

/// Double-back-to-exit when focus is on the shell nav rail.
abstract final class ShellTvBackExit {
  static const Duration promptWindow = Duration(seconds: 2);

  static bool _armed = false;
  static DateTime? _armedAt;

  /// Test hook — defaults to a toast prompt.
  static void Function()? showExitPrompt;

  static void reset() {
    _armed = false;
    _armedAt = null;
  }

  static void onNavBack(VoidCallback exit) {
    final now = DateTime.now();
    if (_armed &&
        _armedAt != null &&
        now.difference(_armedAt!) <= promptWindow) {
      reset();
      exit();
      return;
    }
    _armed = true;
    _armedAt = now;
    (showExitPrompt ?? _defaultPrompt)();
  }

  static void _defaultPrompt() {
    ForjaToast.info(
      'Press back again to exit',
      duration: promptWindow,
    );
  }
}
