import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

/// Desktop window size / placement + player chrome helpers.
///
/// Player leave used to call [WindowManager.unmaximize], and fullscreen enter
/// unmaximized first. On Windows that stamps the restore frame to the boot
/// size — closing any player snapped the window back. Never unmaximize for
/// playback chrome; persist windowed bounds so relaunch keeps place + size.
///
/// Entering host fullscreen captures the current frame; leaving always
/// restores that snapshot (windowed size/place, or maximized) — never a
/// full-screen work-area frame.
class DesktopWindowGeometry {
  DesktopWindowGeometry._();

  static const _kX = 'desktop_window_x';
  static const _kY = 'desktop_window_y';
  static const _kW = 'desktop_window_w';
  static const _kH = 'desktop_window_h';
  static const _kMaximized = 'desktop_window_maximized';

  static Timer? _saveDebounce;

  /// Frame captured immediately before we enter host fullscreen.
  static Rect? _preFullscreenBounds;
  static bool _preFullscreenMaximized = false;
  static bool _hasPreFullscreenSnapshot = false;

  static bool get isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  /// Same clamp as the old bootstrap default (fit primary display).
  static Size defaultSizeForDisplay() {
    const desiredWidth = 1600.0;
    const desiredHeight = 1000.0;
    const screenMargin = 80.0;
    final display = WidgetsBinding.instance.platformDispatcher.displays.first;
    final logicalScreen = display.size / display.devicePixelRatio;
    final maxW = (logicalScreen.width - screenMargin).clamp(
      640.0,
      double.infinity,
    );
    final maxH = (logicalScreen.height - screenMargin).clamp(
      480.0,
      double.infinity,
    );
    return Size(
      desiredWidth.clamp(640.0, maxW),
      desiredHeight.clamp(480.0, maxH),
    );
  }

  static Future<({Size size, Offset? position, bool maximized})>
      loadStartup() async {
    final fallback = defaultSizeForDisplay();
    if (!isDesktop) {
      return (size: fallback, position: null, maximized: false);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final w = prefs.getDouble(_kW);
      final h = prefs.getDouble(_kH);
      if (w == null || h == null || w < 640 || h < 480) {
        return (size: fallback, position: null, maximized: false);
      }
      final x = prefs.getDouble(_kX);
      final y = prefs.getDouble(_kY);
      final maximized = prefs.getBool(_kMaximized) ?? false;
      return (
        size: Size(w, h),
        position: (x != null && y != null) ? Offset(x, y) : null,
        maximized: maximized,
      );
    } catch (_) {
      return (size: fallback, position: null, maximized: false);
    }
  }

  static void scheduleSave() {
    if (!isDesktop) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(saveNow());
    });
  }

  static Future<void> saveNow() async {
    if (!isDesktop) return;
    try {
      // Don't persist host fullscreen or compact PiP as the normal frame.
      if (await windowManager.isFullScreen()) return;
      final size = await windowManager.getSize();
      if (size.width < 500 || size.height < 360) return;

      final pos = await windowManager.getPosition();
      final maximized = await windowManager.isMaximized();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kX, pos.dx);
      await prefs.setDouble(_kY, pos.dy);
      await prefs.setDouble(_kW, size.width);
      await prefs.setDouble(_kH, size.height);
      await prefs.setBool(_kMaximized, maximized);
    } catch (_) {}
  }

  static Future<void> _capturePreFullscreen() async {
    if (await windowManager.isFullScreen()) return;
    final pos = await windowManager.getPosition();
    final size = await windowManager.getSize();
    _preFullscreenBounds = Rect.fromLTWH(
      pos.dx,
      pos.dy,
      size.width,
      size.height,
    );
    _preFullscreenMaximized = await windowManager.isMaximized();
    _hasPreFullscreenSnapshot = true;
  }

  /// After leaving OS fullscreen, force the pre-FS windowed/maximized frame.
  /// Windows often restores to the work-area "full" size otherwise.
  static Future<void> _restorePreFullscreen() async {
    if (!_hasPreFullscreenSnapshot) return;
    final bounds = _preFullscreenBounds;
    final wasMaximized = _preFullscreenMaximized;
    _hasPreFullscreenSnapshot = false;
    _preFullscreenBounds = null;
    _preFullscreenMaximized = false;
    if (bounds == null) return;

    // Let the OS finish leaving fullscreen before we setSize.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    if (wasMaximized) {
      if (!await windowManager.isMaximized()) {
        await windowManager.maximize();
      }
      return;
    }

    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    }
    await windowManager.setSize(Size(bounds.width, bounds.height));
    await windowManager.setPosition(Offset(bounds.left, bounds.top));
  }

  /// Drop OS fullscreen and restore the pre-fullscreen windowed size/place
  /// (or maximized). Never leave the user on a full work-area frame.
  static Future<void> leavePlayerChrome() async {
    if (!isDesktop) return;
    try {
      if (await windowManager.isFullScreen()) {
        await windowManager.setFullScreen(false);
        await _restorePreFullscreen();
      }
      scheduleSave();
    } catch (_) {}
  }

  /// Enter/leave host fullscreen. Enter snapshots the current frame; leave
  /// restores it exactly.
  static Future<bool> toggleFullscreen() async {
    final isFull = await windowManager.isFullScreen();
    if (isFull) {
      await windowManager.setFullScreen(false);
      await _restorePreFullscreen();
      scheduleSave();
      return false;
    }
    await _capturePreFullscreen();
    await windowManager.setFullScreen(true);
    return true;
  }

  static Future<void> enterFullscreen() async {
    if (!isDesktop) return;
    if (await windowManager.isFullScreen()) return;
    await _capturePreFullscreen();
    await windowManager.setFullScreen(true);
  }

  static Future<void> exitFullscreen() async {
    if (!isDesktop) return;
    if (!await windowManager.isFullScreen()) return;
    await windowManager.setFullScreen(false);
    await _restorePreFullscreen();
    scheduleSave();
  }
}
