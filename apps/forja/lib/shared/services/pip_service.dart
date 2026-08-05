// Cross-platform Picture-in-Picture service.
//
// Android: real OS PiP via the `floating` package. The Activity manifest
//          has `android:supportsPictureInPicture="true"` and
//          `android:resizeableActivity="true"`.
//
// Desktop (Windows / macOS): media_kit/mpv has no AVKit/WinUI PiP surface, so
//          we shrink the app window to ~480x270, frameless + always-on-top.
//          macOS also sets collectionBehavior.canJoinAllSpaces (+ fullScreen
//          auxiliary) so the window follows Spaces / fullscreen apps.
//          Toggling off restores the previous bounds and decorations.
//          While a player is bound, switching Mission Control Space /
//          Windows virtual desktop auto-enters PiP if playback is active.
//
// Linux/iOS: no-op (returns false).

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:floating/floating.dart' as fp;
import 'package:window_manager/window_manager.dart';

class PipService {
  PipService._();
  static final PipService instance = PipService._();

  static const _desktopSpaceChannel = EventChannel('forja/desktop_space');

  // ── Android state ──
  final fp.Floating _floating = fp.Floating();

  // ── Desktop state ──
  bool _desktopActive = false;
  /// Set as soon as auto/manual enter starts so lifecycle pause cannot win
  /// the race against async window chrome changes.
  bool _desktopEnterPending = false;
  Rect? _savedBounds; // pre-PiP window bounds
  bool _savedAlwaysOnTop = false;
  bool _savedVisibleOnAllWorkspaces = false;
  final TitleBarStyle _savedTitleBarStyle = TitleBarStyle.hidden;

  // Broadcasts desktop PiP on/off so the player UI can re-render.
  final StreamController<bool> _desktopController =
      StreamController<bool>.broadcast();
  Stream<bool> get desktopPipChanges => _desktopController.stream;

  Object? _autoPipToken;
  bool Function()? _shouldAutoEnterPip;
  StreamSubscription<dynamic>? _desktopSpaceSub;

  bool get isSupported {
    if (kIsWeb) return false;
    if (Platform.isAndroid) return true;
    if (Platform.isWindows || Platform.isMacOS) return true;
    return false;
  }

  bool get isDesktopActive => _desktopActive || _desktopEnterPending;

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

  /// While [token] is bound, Space / virtual-desktop switches that leave the
  /// Forja window auto-enter desktop PiP when [shouldEnter] is true (playing).
  void bindAutoEnterOnDesktopSwitch({
    required Object token,
    required bool Function() shouldEnter,
  }) {
    if (kIsWeb || !(Platform.isMacOS || Platform.isWindows)) return;
    _autoPipToken = token;
    _shouldAutoEnterPip = shouldEnter;
    _ensureDesktopSpaceWatch();
  }

  void unbindAutoEnterOnDesktopSwitch(Object token) {
    if (_autoPipToken != token) return;
    _autoPipToken = null;
    _shouldAutoEnterPip = null;
  }

  void _ensureDesktopSpaceWatch() {
    if (_desktopSpaceSub != null) return;
    _desktopSpaceSub = _desktopSpaceChannel.receiveBroadcastStream().listen(
      (event) {
        unawaited(_onDesktopSpaceEvent(event));
      },
      onError: (Object e) {
        debugPrint('[PipService] desktop_space stream error: $e');
      },
    );
  }

  Future<void> _onDesktopSpaceEvent(dynamic event) async {
    if (_desktopActive) return;
    final shouldEnter = _shouldAutoEnterPip;
    if (shouldEnter == null) return;

    var leftActiveSpace = true;
    if (event is Map) {
      final onActive = event['onActiveSpace'];
      if (onActive is bool) {
        leftActiveSpace = !onActive;
      }
    }
    if (!leftActiveSpace) return;
    if (!shouldEnter()) return;

    await _enterDesktop(width: 16, height: 9);
  }

  // ── Desktop implementation ─────────────────────────────────────────────

  Future<bool> _enterDesktop({required int width, required int height}) async {
    if (_desktopActive) return true;
    if (_desktopEnterPending) return true;
    _desktopEnterPending = true;
    try {
      // Save current state so we can restore.
      final pos = await windowManager.getPosition();
      final size = await windowManager.getSize();
      _savedBounds = Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height);
      _savedAlwaysOnTop = await windowManager.isAlwaysOnTop();
      if (Platform.isMacOS) {
        _savedVisibleOnAllWorkspaces =
            await windowManager.isVisibleOnAllWorkspaces();
      }

      // Pick a reasonable PiP size based on the requested aspect ratio.
      const pipWidth = 480.0;
      final pipHeight = pipWidth * height / width;

      // Stay near the user's current top-left so we don't fight a
      // multi-monitor setup.
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
      if (Platform.isMacOS) {
        // Follow Mission Control Spaces + float over other fullscreen apps.
        await windowManager.setVisibleOnAllWorkspaces(
          true,
          visibleOnFullScreen: true,
        );
      }
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
    } finally {
      _desktopEnterPending = false;
    }
  }

  Future<void> _leaveDesktop() async {
    if (!_desktopActive && _savedBounds == null) return;
    try {
      // Restore window chrome first so the resize/move below feels natural.
      try {
        await windowManager.setTitleBarStyle(
          _savedTitleBarStyle,
          windowButtonVisibility: true,
        );
      } catch (_) {}
      await windowManager.setAlwaysOnTop(_savedAlwaysOnTop);
      if (Platform.isMacOS) {
        await windowManager.setVisibleOnAllWorkspaces(
          _savedVisibleOnAllWorkspaces,
          visibleOnFullScreen: false,
        );
      }
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
      _savedVisibleOnAllWorkspaces = false;
      _desktopController.add(false);
    }
  }
}

/// Local Rect type - avoid pulling dart:ui.Rect into the service public API.
class Rect {
  final double left;
  final double top;
  final double width;
  final double height;
  const Rect.fromLTWH(this.left, this.top, this.width, this.height);
}
