// Cross-platform Picture-in-Picture service.
//
// Android: real OS PiP via the `floating` package.
//
// Desktop (Windows / macOS): media_kit/mpv has no AVKit/WinUI PiP surface, so
// we shrink to a compact always-on-top window with Safari-like behavior:
// rounded floating chrome, aspect lock, dock to bottom-right, throw-to-corner
// snap, and (macOS) AX opt-out so Magnet/Rectangle do not hijack the throw.
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
  static const _desktopPipChannel = MethodChannel('forja/desktop_pip');

  // ── Android state ──
  final fp.Floating _floating = fp.Floating();

  // ── Desktop state ──
  bool _desktopActive = false;
  /// Set as soon as auto/manual enter starts so lifecycle pause cannot win
  /// the race against async window chrome changes.
  bool _desktopEnterPending = false;
  Rect? _savedBounds;
  bool _savedAlwaysOnTop = false;
  bool _savedVisibleOnAllWorkspaces = false;
  final TitleBarStyle _savedTitleBarStyle = TitleBarStyle.hidden;

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

  Future<void> leave() async {
    if (Platform.isWindows || Platform.isMacOS) {
      await _leaveDesktop();
    }
  }

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

  Stream<bool> get androidPipChanges {
    if (!Platform.isAndroid) {
      return const Stream<bool>.empty();
    }
    return _floating.pipStatusStream
        .map((s) => s == fp.PiPStatus.enabled);
  }

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

  /// Safari-style throw: settle to the nearest screen corner.
  Future<void> snapToNearestCorner() async {
    if (!_desktopActive) return;
    try {
      await _desktopPipChannel.invokeMethod('snapToNearestCorner');
    } catch (e) {
      debugPrint('[PipService] snapToNearestCorner failed: $e');
    }
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

  Future<void> _setNativePipChrome(bool enabled) async {
    if (!(Platform.isMacOS || Platform.isWindows)) return;
    try {
      await _desktopPipChannel.invokeMethod('setEnabled', {
        'enabled': enabled,
      });
    } catch (e) {
      debugPrint('[PipService] setEnabled failed: $e');
    }
  }

  Future<void> _dockBottomRight() async {
    try {
      await _desktopPipChannel.invokeMethod('dockBottomRight');
    } catch (e) {
      debugPrint('[PipService] dockBottomRight failed: $e');
    }
  }

  // ── Desktop implementation ─────────────────────────────────────────────

  Future<bool> _enterDesktop({required int width, required int height}) async {
    if (_desktopActive) return true;
    if (_desktopEnterPending) return true;
    _desktopEnterPending = true;
    try {
      final pos = await windowManager.getPosition();
      final size = await windowManager.getSize();
      _savedBounds = Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height);
      _savedAlwaysOnTop = await windowManager.isAlwaysOnTop();
      if (Platform.isMacOS) {
        _savedVisibleOnAllWorkspaces =
            await windowManager.isVisibleOnAllWorkspaces();
      }

      // Safari PiP-ish size (~360 wide), locked aspect.
      const pipWidth = 360.0;
      final aspect = width / height;
      final pipHeight = pipWidth / aspect;
      final maxW = 640.0;
      final maxH = maxW / aspect;

      if (await windowManager.isFullScreen()) {
        await windowManager.setFullScreen(false);
      }
      if (await windowManager.isMaximized()) {
        await windowManager.unmaximize();
      }

      await windowManager.setResizable(true);
      await windowManager.setMinimumSize(Size(240, 240 / aspect));
      await windowManager.setMaximumSize(Size(maxW, maxH));
      await windowManager.setAspectRatio(aspect);
      await windowManager.setSize(Size(pipWidth, pipHeight));

      // Native floating chrome (rounded, Magnet opt-out) before dock.
      await _setNativePipChrome(true);

      await windowManager.setAlwaysOnTop(true);
      if (Platform.isMacOS) {
        await windowManager.setVisibleOnAllWorkspaces(
          true,
          visibleOnFullScreen: true,
        );
      }
      try {
        await windowManager.setAsFrameless();
      } catch (_) {}
      try {
        await windowManager.setHasShadow(true);
      } catch (_) {}
      try {
        await windowManager.setTitleBarStyle(
          TitleBarStyle.hidden,
          windowButtonVisibility: false,
        );
      } catch (_) {}

      // Re-assert native chrome after window_manager style flips.
      await _setNativePipChrome(true);
      await _dockBottomRight();

      _desktopActive = true;
      _desktopController.add(true);
      return true;
    } catch (e) {
      debugPrint('[PipService] _enterDesktop failed: $e');
      await _setNativePipChrome(false);
      return false;
    } finally {
      _desktopEnterPending = false;
    }
  }

  Future<void> _leaveDesktop() async {
    if (!_desktopActive && _savedBounds == null) return;
    try {
      await _setNativePipChrome(false);
      try {
        await windowManager.setAspectRatio(0);
      } catch (_) {}
      try {
        await windowManager.setMaximumSize(Size.infinite);
      } catch (_) {
        try {
          await windowManager.setMaximumSize(const Size(10000, 10000));
        } catch (_) {}
      }
      try {
        await windowManager.setMinimumSize(const Size(640, 480));
      } catch (_) {}
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

class Rect {
  final double left;
  final double top;
  final double width;
  final double height;
  const Rect.fromLTWH(this.left, this.top, this.width, this.height);
}
