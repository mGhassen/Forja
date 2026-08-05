// Cross-platform Picture-in-Picture service.
//
// Android: real OS PiP via the `floating` package.
//
// Desktop (Windows / macOS): media_kit/mpv has no AVKit/WinUI PiP surface, so
// we shrink to a compact always-on-top window with Safari-like chrome:
// rounded floating window, aspect lock, dock to bottom-right on enter,
// and (macOS) AX opt-out so Magnet/Rectangle do not hijack the drag.
// Free drag — no corner snap.
//
// Space / virtual-desktop switch: never pause — arm PiP pending synchronously
// and (macOS) enter via one native call so playback stays fluid.
//
// Linux/iOS: no-op (returns false).

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:floating/floating.dart' as fp;
import 'package:rust/rust.dart';
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

  final StreamController<bool> _desktopController =
      StreamController<bool>.broadcast();
  Stream<bool> get desktopPipChanges => _desktopController.stream;

  Object? _autoPipToken;
  bool Function()? _shouldAutoEnterPip;
  StreamSubscription<dynamic>? _desktopSpaceSub;
  VoidCallback? _autoPipSettingListener;

  bool get isSupported {
    if (kIsWeb) return false;
    if (Platform.isAndroid) return true;
    if (Platform.isWindows || Platform.isMacOS) return true;
    return false;
  }

  bool get isDesktopActive => _desktopActive || _desktopEnterPending;

  /// Player bound for Space-switch auto-PiP — lifecycle must not pause.
  /// Also requires Settings → Auto picture-in-picture.
  bool get autoPipArmed =>
      _shouldAutoEnterPip != null &&
      SettingsService.autoPipOnDesktopSwitchNotifier.value;

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
    _ensureAutoPipSettingListener();
    _syncSpaceLeavePrepAllowed();
  }

  void unbindAutoEnterOnDesktopSwitch(Object token) {
    if (_autoPipToken != token) return;
    _autoPipToken = null;
    _shouldAutoEnterPip = null;
    _syncSpaceLeavePrepAllowed();
    unawaited(_cancelSpaceLeavePrep());
  }

  /// Lifecycle / Space switch: enter PiP instead of pausing. Arms pending
  /// synchronously so a concurrent pause check sees [isDesktopActive].
  Future<void> enterInsteadOfPause({int width = 16, int height = 9}) async {
    if (_desktopActive || _desktopEnterPending) return;
    if (!SettingsService.autoPipOnDesktopSwitchNotifier.value) {
      unawaited(_cancelSpaceLeavePrep());
      return;
    }
    final check = _shouldAutoEnterPip;
    if (check != null && !check()) {
      unawaited(_cancelSpaceLeavePrep());
      return;
    }
    await _enterDesktop(width: width, height: height);
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

  void _ensureAutoPipSettingListener() {
    if (_autoPipSettingListener != null) return;
    void onChanged() => _syncSpaceLeavePrepAllowed();
    _autoPipSettingListener = onChanged;
    SettingsService.autoPipOnDesktopSwitchNotifier.addListener(onChanged);
  }

  void _syncSpaceLeavePrepAllowed() {
    if (kIsWeb || !Platform.isMacOS) return;
    unawaited(_setSpaceLeavePrepAllowed(autoPipArmed));
  }

  Future<void> _setSpaceLeavePrepAllowed(bool allowed) async {
    try {
      await _desktopPipChannel.invokeMethod('setSpaceLeavePrepAllowed', {
        'allowed': allowed,
      });
    } catch (e) {
      debugPrint('[PipService] setSpaceLeavePrepAllowed failed: $e');
    }
  }

  Future<void> _cancelSpaceLeavePrep() async {
    if (kIsWeb || !Platform.isMacOS) return;
    try {
      await _desktopPipChannel.invokeMethod('cancelSpaceLeavePrep');
    } catch (e) {
      debugPrint('[PipService] cancelSpaceLeavePrep failed: $e');
    }
  }

  Future<void> _onDesktopSpaceEvent(dynamic event) async {
    if (_desktopActive || _desktopEnterPending) return;

    var leftActiveSpace = true;
    if (event is Map) {
      final onActive = event['onActiveSpace'];
      if (onActive is bool) {
        leftActiveSpace = !onActive;
      }
    }
    // Back on this Space or Auto PiP not taking over — undo floating prep.
    if (!leftActiveSpace ||
        !SettingsService.autoPipOnDesktopSwitchNotifier.value) {
      await _cancelSpaceLeavePrep();
      return;
    }
    final shouldEnter = _shouldAutoEnterPip;
    if (shouldEnter == null || !shouldEnter()) {
      await _cancelSpaceLeavePrep();
      return;
    }

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

  // ── Desktop implementation ─────────────────────────────────────────────

  Future<bool> _enterDesktop({required int width, required int height}) async {
    if (_desktopActive) return true;
    if (_desktopEnterPending) return true;
    // Sync arm BEFORE any await — lifecycle pause must see this.
    _desktopEnterPending = true;
    _desktopController.add(true);

    const pipWidth = 360.0;
    final aspect = width / height;
    final pipHeight = pipWidth / aspect;

    try {
      _savedAlwaysOnTop = await windowManager.isAlwaysOnTop();
      if (Platform.isMacOS) {
        _savedVisibleOnAllWorkspaces =
            await windowManager.isVisibleOnAllWorkspaces();
        // One native turn: all-spaces → chrome → size → dock.
        final saved = await _desktopPipChannel.invokeMethod<dynamic>(
          'enterPip',
          {'width': pipWidth, 'height': pipHeight},
        );
        if (saved is Map) {
          _savedBounds = Rect.fromLTWH(
            (saved['x'] as num?)?.toDouble() ?? 0,
            (saved['y'] as num?)?.toDouble() ?? 0,
            (saved['width'] as num?)?.toDouble() ?? 1280,
            (saved['height'] as num?)?.toDouble() ?? 720,
          );
        }
        try {
          await windowManager.setMinimumSize(Size(240, 240 / aspect));
          await windowManager.setMaximumSize(Size(640, 640 / aspect));
          await windowManager.setAspectRatio(aspect);
        } catch (_) {}
        await windowManager.setAlwaysOnTop(true);
        _desktopActive = true;
        return true;
      }

      // Windows: stepwise (no atomic native enter yet).
      final pos = await windowManager.getPosition();
      final size = await windowManager.getSize();
      _savedBounds = Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height);

      if (await windowManager.isFullScreen()) {
        await windowManager.setFullScreen(false);
      }
      if (await windowManager.isMaximized()) {
        await windowManager.unmaximize();
      }

      await windowManager.setResizable(true);
      await windowManager.setMinimumSize(Size(240, 240 / aspect));
      await windowManager.setMaximumSize(Size(640, 640 / aspect));
      await windowManager.setAspectRatio(aspect);
      await windowManager.setSize(Size(pipWidth, pipHeight));
      await _setNativePipChrome(true);
      await windowManager.setAlwaysOnTop(true);
      try {
        await windowManager.setHasShadow(true);
      } catch (_) {}
      try {
        await _desktopPipChannel.invokeMethod('dockBottomRight');
      } catch (_) {}

      _desktopActive = true;
      return true;
    } catch (e) {
      debugPrint('[PipService] _enterDesktop failed: $e');
      await _setNativePipChrome(false);
      _desktopController.add(false);
      return false;
    } finally {
      _desktopEnterPending = false;
    }
  }

  Future<void> _leaveDesktop() async {
    if (!_desktopActive && _savedBounds == null) {
      await _cancelSpaceLeavePrep();
      return;
    }
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
