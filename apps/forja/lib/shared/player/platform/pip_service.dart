// Cross-platform Picture-in-Picture service.
//
// Android: real OS PiP via the `floating` package.
//
// Desktop (Windows / macOS): secondary always-on-top float window hosts video
// via exclusive media_kit Player handoff. Main Forja window stays full-size
// with a placeholder ("Playing in picture-in-picture") and shell unlocked.
//
// Space / virtual-desktop switch: never pause — arm PiP pending synchronously
// and enter the float so playback stays fluid.
//
// Linux/iOS: no-op (returns false).

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:floating/floating.dart' as fp;
import 'package:forja/shared/player/in_app_mini/in_app_mini_player_controller.dart';
import 'package:forja/shared/player/platform/pip_handoff.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:rust/rust.dart';

class PipService {
  PipService._();
  static final PipService instance = PipService._();

  static const _desktopSpaceChannel = EventChannel('forja/desktop_space');
  static const _desktopPipChannel = MethodChannel('forja/desktop_pip');

  final fp.Floating _floating = fp.Floating();

  bool _desktopActive = false;
  bool _desktopEnterPending = false;
  PipHandoffSnapshot? _lastSnapshot;

  final StreamController<bool> _desktopController =
      StreamController<bool>.broadcast();
  Stream<bool> get desktopPipChanges => _desktopController.stream;

  Object? _autoPipToken;
  bool Function()? _shouldAutoEnterPip;
  StreamSubscription<dynamic>? _desktopSpaceSub;
  VoidCallback? _autoPipSettingListener;

  PipHandoffSession? _handoff;

  bool get isSupported {
    if (kIsWeb) return false;
    if (Platform.isAndroid) return true;
    if (Platform.isWindows || Platform.isMacOS) return true;
    return false;
  }

  bool get isDesktopActive => _desktopActive || _desktopEnterPending;

  bool get autoPipArmed =>
      _shouldAutoEnterPip != null &&
      SettingsService.autoPipOnDesktopSwitchNotifier.value;

  void bindHandoff(PipHandoffSession session) {
    _handoff = session;
  }

  void unbindHandoff(PipHandoffSession session) {
    if (identical(_handoff, session)) {
      _handoff = null;
    }
  }

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
        return _enterDesktopFloat(width: width, height: height);
      }
    } catch (e) {
      debugPrint('[PipService] enter failed: $e');
    }
    return false;
  }

  Future<void> leave() async {
    if (Platform.isWindows || Platform.isMacOS) {
      await _leaveDesktopFloat(restoreMain: true);
    }
  }

  /// Tear down the float without restoring the main Player (player disposing).
  Future<void> abandonFloat() async {
    if (Platform.isWindows || Platform.isMacOS) {
      await _leaveDesktopFloat(restoreMain: false);
    }
  }

  Future<bool> toggle({int width = 16, int height = 9}) async {
    if (Platform.isWindows || Platform.isMacOS) {
      if (_desktopActive || _desktopEnterPending) {
        await _leaveDesktopFloat(restoreMain: true);
        return false;
      }
      return _enterDesktopFloat(width: width, height: height);
    }
    return enter(width: width, height: height);
  }

  Stream<bool> get androidPipChanges {
    if (!Platform.isAndroid) {
      return const Stream<bool>.empty();
    }
    return _floating.pipStatusStream.map((s) => s == fp.PiPStatus.enabled);
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
    await _enterDesktopFloat(width: width, height: height);
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

    await _enterDesktopFloat(width: 16, height: 9);
  }

  Future<bool> _enterDesktopFloat({
    required int width,
    required int height,
  }) async {
    if (_desktopActive) return true;
    if (_desktopEnterPending) return true;
    if (InAppMiniPlayerController.instance.isActive) {
      debugPrint('[PipService] refuse PiP while in-app mini is active');
      return false;
    }
    final session = _handoff;
    if (session == null) {
      debugPrint('[PipService] no PipHandoffSession bound');
      return false;
    }

    _desktopEnterPending = true;
    _desktopController.add(true);

    try {
      final snap = await session.captureForPip();
      if (snap == null || snap.url.isEmpty) {
        _desktopController.add(false);
        return false;
      }
      _lastSnapshot = snap;

      final pipWidth = 360.0;
      final aspect = snap.aspectWidth / snap.aspectHeight;
      final pipHeight = pipWidth / aspect;

      await session.releasePlayerForPip();
      ShellBus.leavePlayerSurface();
      ShellBus.clearMaskShellUnderPlayer();

      _desktopPipChannel.setMethodCallHandler(_onNativePipCall);

      final ok = await _desktopPipChannel.invokeMethod<bool>('createFloat', {
        'width': pipWidth,
        'height': pipHeight,
      });
      if (ok != true) {
        await session.restoreFromPip(snap);
        ShellBus.enterPlayerSurface();
        _desktopController.add(false);
        return false;
      }

      await _desktopPipChannel.invokeMethod('openFloat', snap.toMap());
      _desktopActive = true;
      return true;
    } catch (e) {
      debugPrint('[PipService] _enterDesktopFloat failed: $e');
      final snap = _lastSnapshot;
      final session = _handoff;
      if (snap != null && session != null) {
        try {
          await session.restoreFromPip(snap);
          ShellBus.enterPlayerSurface();
        } catch (_) {}
      }
      _desktopController.add(false);
      return false;
    } finally {
      _desktopEnterPending = false;
    }
  }

  Future<dynamic> _onNativePipCall(MethodCall call) async {
    switch (call.method) {
      case 'floatExpand':
        final args = call.arguments;
        PipHandoffSnapshot? snap = _lastSnapshot;
        if (args is Map && snap != null) {
          snap = PipHandoffSnapshot(
            url: snap.url,
            headers: snap.headers,
            providerId: snap.providerId,
            position: Duration(
              milliseconds: (args['positionMs'] as num?)?.toInt() ??
                  snap.position.inMilliseconds,
            ),
            playing: args['playing'] == true,
            aspectWidth: snap.aspectWidth,
            aspectHeight: snap.aspectHeight,
            isLive: snap.isLive,
          );
          _lastSnapshot = snap;
        }
        await _leaveDesktopFloat(restoreMain: true);
        return null;
      case 'floatClose':
        await _leaveDesktopFloat(restoreMain: false, closeSession: true);
        return null;
      default:
        throw MissingPluginException(call.method);
    }
  }

  Future<void> _leaveDesktopFloat({
    required bool restoreMain,
    bool closeSession = false,
  }) async {
    if (!_desktopActive && !_desktopEnterPending && _lastSnapshot == null) {
      await _cancelSpaceLeavePrep();
      return;
    }
    try {
      await _desktopPipChannel.invokeMethod('destroyFloat');
    } catch (e) {
      debugPrint('[PipService] destroyFloat failed: $e');
    }
    try {
      _desktopPipChannel.setMethodCallHandler(null);
    } catch (_) {}

    final session = _handoff;
    final snap = _lastSnapshot;
    _lastSnapshot = null;
    _desktopActive = false;
    _desktopEnterPending = false;
    _desktopController.add(false);
    await _cancelSpaceLeavePrep();

    if (session == null) return;
    if (closeSession) {
      await session.closeFromPip();
      return;
    }
    if (restoreMain && snap != null) {
      await session.restoreFromPip(snap);
      ShellBus.enterPlayerSurface();
    }
  }
}
