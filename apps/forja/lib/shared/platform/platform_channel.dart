import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/platform/android_form_factor.dart';
import 'package:forja/shared/platform/platform_info.dart';
import 'package:rust/rust.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Resolves [PlatformProfile] and configures [SettingsService] at boot.
abstract final class PlatformChannel {
  static const MethodChannel _channel = MethodChannel('forja/platform');

  /// Debug / CI: `flutter run --flavor tv --dart-define=FORJA_ANDROID_TV=true`
  /// on Android. The mobile flavor never uses the TV profile.
  static const bool forceAndroidTv = bool.fromEnvironment(
    'FORJA_ANDROID_TV',
    defaultValue: false,
  );

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
      await _readAndroidBuildFacts();
      return androidProfileFor(
        formFactor: PlatformInfo.androidFormFactor,
        forceTv: forceAndroidTv,
        nativeTv: PlatformInfo.nativeAndroidTv,
        physicalTvPanel: _physicalAndroidTvPanel(),
      );
    }
    return PlatformProfile.phone;
  }

  /// Android profile from build flavor + device facts.
  ///
  /// Mobile flavor is always [PlatformProfile.phone] (tablets included). TV
  /// flavor keeps native leanback detection plus the panel-size fallback.
  @visibleForTesting
  static PlatformProfile androidProfileFor({
    required AndroidFormFactor formFactor,
    required bool forceTv,
    required bool nativeTv,
    required bool physicalTvPanel,
  }) {
    if (formFactor == AndroidFormFactor.mobile) return PlatformProfile.phone;
    if (forceTv || nativeTv) return PlatformProfile.androidTv;
    // Keep playback caps aligned with [ShellTokens.isAndroidTvDevice] when the
    // leanback channel fails but the panel still looks like a TV (720p+ 16:9).
    if (physicalTvPanel) return PlatformProfile.androidTv;
    return PlatformProfile.phone;
  }

  static Future<void>? _androidFacts;

  /// Build flavor + native TV answer. Both are fixed for the process.
  static Future<void> _readAndroidBuildFacts() =>
      _androidFacts ??= _queryAndroidBuildFacts();

  static Future<void> _queryAndroidBuildFacts() async {
    String? rawFormFactor;
    try {
      rawFormFactor = await _channel.invokeMethod<String>('formFactor');
    } catch (e) {
      debugPrint('[PlatformChannel] formFactor failed: $e');
    }
    // `--flavor` also sets FLUTTER_APP_FLAVOR at compile time.
    PlatformInfo.androidFormFactor = AndroidFormFactor.parse(
      rawFormFactor ?? appFlavor,
    );
    try {
      PlatformInfo.nativeAndroidTv =
          await _channel.invokeMethod<bool>('isAndroidTv') == true;
    } catch (e) {
      debugPrint('[PlatformChannel] isAndroidTv failed: $e');
    }
    try {
      PlatformInfo.nativeTouchscreen =
          await _channel.invokeMethod<bool>('hasTouchscreen') == true;
    } catch (e) {
      debugPrint('[PlatformChannel] hasTouchscreen failed: $e');
    }
  }

  /// Same heuristic as [ShellTokens.isAndroidTvDevice] physical fallback.
  static bool _physicalAndroidTvPanel() {
    final views = SchedulerBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return false;
    return ShellTokens.looksLikeAndroidTvPanel(views.first.physicalSize);
  }

  static Future<void> initialize() async {
    final profile = await detectProfile();
    SettingsService.configurePlatformProfile(profile);
    ShellTokens.androidMobileFormFactor = Platform.isAndroid &&
        PlatformInfo.androidFormFactor == AndroidFormFactor.mobile;
    ShellTokens.nativeAndroidTvDetected = profile == PlatformProfile.androidTv;
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
    // Hydrate live notifiers that use platform-aware fallbacks.
    await SettingsService().getPlayInBackground();
    await SettingsService().getTvNavSound();
  }

  /// Android TV only — one-shot Chromium warm-up. Prefer [TvWebViewWarm.ensure]
  /// so boot does not pay this cost.
  static Future<void> prepareWebViewForTv() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('prepareWebViewForTv');
    } catch (e) {
      debugPrint('[PlatformChannel] prepareWebViewForTv failed: $e');
    }
  }

  /// Android TV: stop underlay WebView / Exo PlayerView from eating leanback
  /// keys (Live Sports Streamed keeps the embed WebView under the native
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

  /// Android TV: switch HDMI / panel mode so refresh divides cleanly into
  /// [fps] (issue 150 MediaKit / 151 Exo). No-op when already clean or no mode.
  static Future<void> applyDisplayFrameRate(double fps) async {
    if (!Platform.isAndroid || fps <= 0) return;
    try {
      await _channel.invokeMethod<void>('applyDisplayFrameRate', {'fps': fps});
    } catch (e) {
      debugPrint('[PlatformChannel] applyDisplayFrameRate failed: $e');
    }
  }

  /// Restore the system display mode after MediaKit IPTV leaves the player.
  static Future<void> clearDisplayFrameRate() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('clearDisplayFrameRate');
    } catch (e) {
      debugPrint('[PlatformChannel] clearDisplayFrameRate failed: $e');
    }
  }

  /// Android TV leanback UI tick (`AudioManager.playSoundEffect`).
  ///
  /// [kind]: `up` / `down` / `left` / `right` / `activate`.
  static Future<void> playSoundEffect(String kind) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('playSoundEffect', {'kind': kind});
    } catch (e) {
      debugPrint('[PlatformChannel] playSoundEffect failed: $e');
    }
  }

  /// Hold [WifiManager.MulticastLock] while browsing mDNS (LAN Discover).
  /// No-op off Android. Pair with [releaseWifiMulticastLock].
  static Future<void> acquireWifiMulticastLock() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('acquireWifiMulticastLock');
    } catch (e) {
      debugPrint('[PlatformChannel] acquireWifiMulticastLock failed: $e');
    }
  }

  /// Release one [acquireWifiMulticastLock] hold (refcount).
  static Future<void> releaseWifiMulticastLock() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('releaseWifiMulticastLock');
    } catch (e) {
      debugPrint('[PlatformChannel] releaseWifiMulticastLock failed: $e');
    }
  }
}
