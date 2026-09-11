import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

/// Brings the desktop window forward after an external handoff (web login, deep link).
abstract final class DesktopWindowFocus {
  /// Test hook — skips `window_manager` when set.
  @visibleForTesting
  static Future<void> Function()? bringToFrontOverride;

  static Future<void> bringToFront() async {
    final override = bringToFrontOverride;
    if (override != null) {
      await override();
      return;
    }
    if (kIsWeb) return;
    if (!(Platform.isMacOS || Platform.isWindows || Platform.isLinux)) return;
    try {
      if (await windowManager.isMinimized()) {
        await windowManager.restore();
      }
      await windowManager.show();
      await windowManager.focus();
    } catch (e, st) {
      debugPrint('[DesktopWindowFocus] bring to front failed: $e\n$st');
    }
  }
}
