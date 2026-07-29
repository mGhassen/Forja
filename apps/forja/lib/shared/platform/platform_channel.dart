import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/platform/platform_info.dart';
import 'package:rust/rust.dart';

/// Resolves [PlatformProfile] and configures [SettingsService] at boot.
abstract final class PlatformChannel {
  static const MethodChannel _channel = MethodChannel('forja/platform');

  /// Debug / CI: `flutter run --dart-define=FORJA_ANDROID_TV=true` on Android.
  static const bool forceAndroidTv =
      bool.fromEnvironment('FORJA_ANDROID_TV', defaultValue: false);

  static PlatformProfile? _debugOverride;

  @visibleForTesting
  static set debugOverrideProfile(PlatformProfile? profile) {
    _debugOverride = profile;
  }

  static Future<PlatformProfile> detectProfile() async {
    if (_debugOverride != null) return _debugOverride!;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return PlatformProfile.desktop;
    }
    if (Platform.isAndroid) {
      if (forceAndroidTv) return PlatformProfile.androidTv;
      try {
        final isTv = await _channel.invokeMethod<bool>('isAndroidTv');
        if (isTv == true) return PlatformProfile.androidTv;
      } catch (e) {
        debugPrint('[PlatformChannel] isAndroidTv failed: $e');
      }
      // Keep playback caps aligned with [ShellTokens.isAndroidTvDevice] when the
      // leanback channel fails but the panel still looks like a TV (1080p+).
      if (_physicalAndroidTvPanel()) return PlatformProfile.androidTv;
      return PlatformProfile.phone;
    }
    return PlatformProfile.phone;
  }

  /// Same heuristic as [ShellTokens.isAndroidTvDevice] physical fallback.
  static bool _physicalAndroidTvPanel() {
    final views = SchedulerBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return false;
    final physical = views.first.physicalSize;
    return physical.shortestSide >= 1080 && physical.width > physical.height;
  }

  static Future<void> initialize() async {
    final profile = await detectProfile();
    SettingsService.configurePlatformProfile(profile);
    ShellTokens.nativeAndroidTvDetected =
        profile == PlatformProfile.androidTv;
    PlatformInfo.isAndroidEmulator = await _detectAndroidEmulator();
    // Platform defaults seed after Engine.init() - see bootstrapForja.
    unawaited(DeviceCapabilitiesService.detect(platformProfile: profile));
  }

  static Future<bool> _detectAndroidEmulator() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isAndroidEmulator') == true;
    } catch (e) {
      debugPrint('[PlatformChannel] isAndroidEmulator failed: $e');
      return false;
    }
  }

  /// Seed platform defaults once the Rust KV file is open.
  static Future<void> seedPlatformDefaultsAfterEngine() async {
    final profile = await detectProfile();
    SettingsService.configurePlatformProfile(profile);
    await SettingsService().ensurePlatformDefaultsSeeded(profile);
  }

  /// Android TV only - software WebView warm-up before first real WebView use.
  static Future<void> prepareWebViewForTv() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('prepareWebViewForTv');
    } catch (e) {
      debugPrint('[PlatformChannel] prepareWebViewForTv failed: $e');
    }
  }

  /// Android TV: stop underlay WebView / Exo PlayerView from eating leanback
  /// keys (Live Matches Streamed keeps the embed WebView under the native
  /// player for CDN fetches). Safe no-op on phone / when no underlay exists.
  static Future<void> releaseUnderlayPlatformViewFocus() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('releaseUnderlayPlatformViewFocus');
    } catch (e) {
      debugPrint(
        '[PlatformChannel] releaseUnderlayPlatformViewFocus failed: $e',
      );
    }
  }

  /// Finish the task and kill the process so the next launch is cold.
  /// Used by Android TV double Back (nav) / double Exit — not phone Back.
  static Future<void> exitAppCompletely() async {
    if (!Platform.isAndroid) {
      await SystemNavigator.pop();
      return;
    }
    try {
      await _channel.invokeMethod<void>('exitAppCompletely');
    } catch (e) {
      debugPrint('[PlatformChannel] exitAppCompletely failed: $e');
      await SystemNavigator.pop();
    }
  }
}
