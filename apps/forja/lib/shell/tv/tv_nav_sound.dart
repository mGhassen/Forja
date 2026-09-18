import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:forja/shared/engine/runtime/shell/shell_bus.dart';
import 'package:forja/shared/platform/platform_channel.dart';
import 'package:forja/shared/platform/platform_info.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart'
    show shellTvIsActivateKey;
import 'package:forja/shell/tv/shell_tv_focus.dart' show shellTvIsNavigationKey;
import 'package:rust/rust.dart';

/// Android TV D-pad focus / OK system UI sounds (issue 293).
///
/// Silent while [ShellBus.playerSurfaceActive] or Settings toggle off.
abstract final class TvNavSound {
  TvNavSound._();

  static bool _installed = false;

  static bool get _atv =>
      PlatformInfo.isAndroidTv || PlatformChannel.forceAndroidTv;

  static bool get _enabled =>
      _atv && SettingsService.tvNavSoundNotifier.value;

  /// Call once after [PlatformChannel.initialize] on Android.
  static void install() {
    if (_installed || !Platform.isAndroid || !_atv) return;
    _installed = true;
    HardwareKeyboard.instance.addHandler(_onKey);
    unawaited(SettingsService().getTvNavSound());
  }

  @visibleForTesting
  static void resetForTest() {
    if (!_installed) return;
    HardwareKeyboard.instance.removeHandler(_onKey);
    _installed = false;
  }

  static bool _onKey(KeyEvent event) {
    if (!_enabled) return false;
    if (ShellBus.playerSurfaceActive.value) return false;

    if (shellTvIsActivateKey(event)) {
      unawaited(PlatformChannel.playSoundEffect('activate'));
      return false;
    }

    if (!shellTvIsNavigationKey(event)) return false;
    final kind = _kindForArrow(event.logicalKey);
    if (kind == null) return false;

    // HardwareKeyboard runs before Focus onKeyEvent — capture focus now, then
    // play only if a neighbor actually took focus this frame.
    final before = FocusManager.instance.primaryFocus;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_enabled) return;
      if (ShellBus.playerSurfaceActive.value) return;
      final after = FocusManager.instance.primaryFocus;
      if (identical(before, after)) return;
      unawaited(PlatformChannel.playSoundEffect(kind));
    });
    return false;
  }

  static String? _kindForArrow(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowUp) return 'up';
    if (key == LogicalKeyboardKey.arrowDown) return 'down';
    if (key == LogicalKeyboardKey.arrowLeft) return 'left';
    if (key == LogicalKeyboardKey.arrowRight) return 'right';
    return null;
  }
}
