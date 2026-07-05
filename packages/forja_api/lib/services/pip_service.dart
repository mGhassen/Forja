// Cross-platform Picture-in-Picture service.
//
// Android: real OS PiP via the `floating` package. The Activity manifest
//          has `android:supportsPictureInPicture="true"` and
//          `android:resizeableActivity="true"`.
//
// Windows / macOS: there is no OS-level PiP for arbitrary apps, so we
//          simulate it: shrink the window to ~480x270, make it
//          frameless + always-on-top, dock to the bottom-right corner.
//          Toggling off restores the previous bounds and decorations.
//
// Linux/iOS: no-op (returns false).

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show Size, Offset;

import 'package:flutter/foundation.dart';
import 'package:floating/floating.dart' as fp;
import 'package:window_manager/window_manager.dart';

class PipService {
  PipService._();
  static final PipService instance = PipService._();

  // ── Android state ──
  final fp.Floating _floating = fp.Floating();

  // ── Desktop state ──
  bool _desktopActive = false;
  Rect? _savedBounds;       // pre-PiP window bounds
  bool _savedAlwaysOnTop = false;
  final TitleBarStyle _savedTitleBarStyle = TitleBarStyle.normal;

  // Broadcasts desktop PiP on/off so the player UI can re-render.
  final StreamController<bool> _desktopController =
      StreamController<bool>.broadcast();
  Stream<bool> get desktopPipChanges => _desktopController.stream;

  bool get isSupported {
    if (kIsWeb) return false;
    if (Platform.isAndroid) return true;
    if (Platform.isWindows || Platform.isMacOS) return true;
    return false;
  }

  bool get isDesktopActive => _desktopActive;

  /// Enter PiP. Returns true on success.
  Future<bool> enter({
    int width = 16,
    int height = 9,
  }) async {
    if (!isSupported) return false;
    try {
      if (Platform.isAndroid) {
        final status = await _floating.enable(
          fp.ImmediatePiP(
            aspectRatio: fp.Rational(width, height),
          ),
        );
        return status == fp.PiPStatus.enabled;
      }
      if (Platform.isWindows || Platform.isMacOS) {
        return _enterDesktop(width: width, height: height);
      }
    } catch (e) {
      debugPrint('[PipService] enter failed: $e');
    }
    return false;
  }

  /// Leave desktop PiP. Android leaves PiP automatically when the user
  /// taps the window or fullscreens it; this is a no-op there.
  Future<void> leave() async {
    if (Platform.isWindows || Platform.isMacOS) {
      await _leaveDesktop();
    }
  }

  /// Toggle desktop PiP on/off. On Android just enters (the OS handles exit).
  Future<bool> toggle({int width = 16, int height = 9}) async {
    if (Platform.isWindows || Platform.isMacOS) {
      if (_desktopActive) {
        await _leaveDesktop();
        return false;
      }
      return _enterDesktop(width: width, height: height);
    }
    return enter(width: width, height: height);
  }

  /// Stream of Android PiP transitions (entered/exited). Empty on desktop.
  Stream<bool> get androidPipChanges {
    if (!Platform.isAndroid) {
      return const Stream<bool>.empty();
    }
    return _floating.pipStatusStream
        .map((s) => s == fp.PiPStatus.enabled);
  }

  // ── Desktop implementation ─────────────────────────────────────────────

  Future<bool> _enterDesktop({required int width, required int height}) async {
    try {
      // Save current state so we can restore.
      final pos = await windowManager.getPosition();
      final size = await windowManager.getSize();
      _savedBounds = Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height);
      _savedAlwaysOnTop = await windowManager.isAlwaysOnTop();

      // Pick a reasonable PiP size based on the requested aspect ratio.
      const pipWidth = 480.0;
      final pipHeight = pipWidth * height / width;

      // Stay near the user's current top-left so we don't fight a
      // multi-monitor setup. Just nudge a little to the right/down so
      // the smaller window isn't anchored to the same corner.
      final dockX = pos.dx;
      final dockY = pos.dy;

      if (await windowManager.isFullScreen()) {
        await windowManager.setFullScreen(false);
      }
      if (await windowManager.isMaximized()) {
        await windowManager.unmaximize();
      }

      await windowManager.setResizable(true);
      await windowManager.setMinimumSize(const Size(240, 135));
      await windowManager.setSize(Size(pipWidth, pipHeight));
      await windowManager.setPosition(Offset(dockX, dockY));
      await windowManager.setAlwaysOnTop(true);
      // Hide the OS title bar / window chrome so only video shows.
      try {
        await windowManager.setTitleBarStyle(
          TitleBarStyle.hidden,
          windowButtonVisibility: false,
        );
      } catch (_) {}
      _desktopActive = true;
      _desktopController.add(true);
      return true;
    } catch (e) {
      debugPrint('[PipService] _enterDesktop failed: $e');
      return false;
    }
  }

  Future<void> _leaveDesktop() async {
    try {
      // Restore window chrome first so the resize/move below feels natural.
      try {
        await windowManager.setTitleBarStyle(
          _savedTitleBarStyle,
          windowButtonVisibility: true,
        );
      } catch (_) {}
      await windowManager.setAlwaysOnTop(_savedAlwaysOnTop);
      final b = _savedBounds;
      if (b != null) {
        await windowManager.setSize(Size(b.width, b.height));
        await windowManager.setPosition(Offset(b.left, b.top));
      }
    } catch (e) {
      debugPrint('[PipService] _leaveDesktop failed: $e');
    } finally {
      _desktopActive = false;
      _savedBounds = null;
      _desktopController.add(false);
    }
  }
}

/// Local Rect type — avoid pulling dart:ui.Rect into the service public API.
class Rect {
  final double left;
  final double top;
  final double width;
  final double height;
  const Rect.fromLTWH(this.left, this.top, this.width, this.height);
}
