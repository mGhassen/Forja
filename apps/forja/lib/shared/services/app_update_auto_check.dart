import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/services/app_update_auto_check_policy.dart';
import 'package:forja/shared/services/app_updater_service.dart';
import 'package:forja/shared/widgets/update_dialog.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:rust/rust.dart';

/// In-session update auto-check while [MainScreen] is alive (RFC-015).
///
/// Cold start still runs the blocking gate in [DesktopStartupGate]. This
/// coordinator covers long-running sessions: periodic + resume checks, deferred
/// until no video player is open, respecting dismissed version + check throttle.
class AppUpdateAutoCheck {
  AppUpdateAutoCheck({
    AppUpdaterService? updater,
    SettingsService? settings,
    this.interval = AppUpdateAutoCheckPolicy.minCheckInterval,
  })  : _updater = updater ?? AppUpdaterService(),
        _settings = settings ?? SettingsService();

  final AppUpdaterService _updater;
  final SettingsService _settings;
  final Duration interval;

  Timer? _timer;
  bool _started = false;
  bool _checking = false;
  bool _dialogOpen = false;
  bool _pendingAfterPlayer = false;
  UpdateInfo? _pendingInfo;
  BuildContext Function()? _contextGetter;

  /// Start periodic checks. Safe to call once from [MainScreen.initState].
  void start(BuildContext Function() contextGetter) {
    if (_started) return;
    _started = true;
    _contextGetter = contextGetter;
    ShellBus.playerSurfaceActive.addListener(_onPlayerSurfaceChanged);
    // First tick after the shell paints — cold start usually already checked,
    // so the throttle skips; still covers hot-restart / failed gate cases.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(maybeCheck(reason: 'shell_open'));
    });
    _timer = Timer.periodic(interval, (_) {
      unawaited(maybeCheck(reason: 'periodic'));
    });
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    if (_started) {
      ShellBus.playerSurfaceActive.removeListener(_onPlayerSurfaceChanged);
    }
    _started = false;
    _contextGetter = null;
    _pendingAfterPlayer = false;
    _pendingInfo = null;
  }

  /// Call from [WidgetsBindingObserver.didChangeAppLifecycleState] on resume.
  void onResumed() {
    unawaited(maybeCheck(reason: 'resume'));
  }

  void _onPlayerSurfaceChanged() {
    if (ShellBus.playerSurfaceActive.value) return;
    if (_pendingInfo != null) {
      _pendingAfterPlayer = false;
      unawaited(_showIfAllowed(_pendingInfo!, reason: 'after_player'));
      return;
    }
    if (_pendingAfterPlayer) {
      _pendingAfterPlayer = false;
      unawaited(maybeCheck(reason: 'after_player', forceNetwork: true));
    }
  }

  /// Record that the user skipped an offered version (Later / Skip for now).
  static Future<void> recordDismissed(String version) async {
    await SettingsService().setUpdateDismissedVersion(version);
  }

  /// Stamp last-check time (also used by the cold-start gate).
  static Future<void> recordCheckCompleted() async {
    await SettingsService().setUpdateLastCheckAt(DateTime.now().toUtc());
  }

  Future<void> maybeCheck({
    required String reason,
    bool forceNetwork = false,
  }) async {
    if (!_started || _checking || _dialogOpen) return;
    final ctxGetter = _contextGetter;
    if (ctxGetter == null) return;

    _checking = true;
    try {
      final enabled = await _settings.isUpdateAutoCheckEnabled();
      if (!enabled) return;

      final last = await _settings.getUpdateLastCheckAt();
      final now = DateTime.now().toUtc();
      if (!forceNetwork &&
          !AppUpdateAutoCheckPolicy.shouldNetworkCheck(
            now: now,
            lastCheckAt: last,
            autoCheckEnabled: true,
            interval: interval,
          )) {
        return;
      }

      if (ShellBus.playerSurfaceActive.value) {
        _pendingAfterPlayer = true;
        debugPrint('[AppUpdateAutoCheck] defer ($reason): player active');
        return;
      }

      final result = await _updater.checkForUpdates();
      await recordCheckCompleted();

      if (!result.isAvailable || result.info == null) {
        if (result.isFailed) {
          debugPrint(
            '[AppUpdateAutoCheck] check failed ($reason): '
            '${result.failureMessage}',
          );
        }
        return;
      }

      await _showIfAllowed(result.info!, reason: reason);
    } catch (e) {
      debugPrint('[AppUpdateAutoCheck] error ($reason): $e');
    } finally {
      _checking = false;
    }
  }

  Future<void> _showIfAllowed(UpdateInfo info, {required String reason}) async {
    if (_dialogOpen) return;

    final dismissed = await _settings.getUpdateDismissedVersion();
    if (!AppUpdateAutoCheckPolicy.shouldPrompt(
      latestVersion: info.latestVersion,
      dismissedVersion: dismissed,
    )) {
      _pendingInfo = null;
      debugPrint(
        '[AppUpdateAutoCheck] skip prompt ($reason): '
        '${info.latestVersion} dismissed',
      );
      return;
    }

    if (ShellBus.playerSurfaceActive.value) {
      _pendingInfo = info;
      _pendingAfterPlayer = true;
      debugPrint('[AppUpdateAutoCheck] defer show ($reason): player active');
      return;
    }

    final ctxGetter = _contextGetter;
    if (ctxGetter == null) return;
    final context = ctxGetter();
    if (!context.mounted) return;

    _pendingInfo = null;
    _dialogOpen = true;
    try {
      debugPrint(
        '[AppUpdateAutoCheck] showing ${info.latestVersion} ($reason)',
      );
      await UpdateDialog.show(context, info);
    } finally {
      _dialogOpen = false;
    }
  }
}
