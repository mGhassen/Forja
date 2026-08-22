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
class DesktopWindowGeometry {
  DesktopWindowGeometry._();

  static const _kX = 'desktop_window_x';
  static const _kY = 'desktop_window_y';
  static const _kW = 'desktop_window_w';
  static const _kH = 'desktop_window_h';
  static const _kMaximized = 'desktop_window_maximized';

  static Timer? _saveDebounce;

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

  /// Drop OS fullscreen only. Never unmaximize — that resets Windows to the
  /// pre-maximize (often boot) frame when leaving any player.
  static Future<void> leavePlayerChrome() async {
    if (!isDesktop) return;
    try {
      if (await windowManager.isFullScreen()) {
        await windowManager.setFullScreen(false);
      }
      scheduleSave();
    } catch (_) {}
  }

  /// Enter/leave host fullscreen without unmaximize-first (Windows restore
  /// frame must stay the user's windowed/maximized size).
  static Future<bool> toggleFullscreen() async {
    final isFull = await windowManager.isFullScreen();
    await windowManager.setFullScreen(!isFull);
    if (isFull) scheduleSave();
    return !isFull;
  }

  static Future<void> enterFullscreen() async {
    if (!isDesktop) return;
    if (!await windowManager.isFullScreen()) {
      await windowManager.setFullScreen(true);
    }
  }

  static Future<void> exitFullscreen() async {
    if (!isDesktop) return;
    if (await windowManager.isFullScreen()) {
      await windowManager.setFullScreen(false);
      scheduleSave();
    }
  }
}
