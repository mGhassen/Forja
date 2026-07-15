import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/design/design.dart';
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
      return PlatformProfile.phone;
    }
    return PlatformProfile.phone;
  }

  static Future<void> initialize() async {
    final profile = await detectProfile();
    SettingsService.configurePlatformProfile(profile);
    ShellTokens.nativeAndroidTvDetected =
        profile == PlatformProfile.androidTv;
    // Platform defaults seed after Engine.init() — see bootstrapForja.
    unawaited(DeviceCapabilitiesService.detect(platformProfile: profile));
  }

  /// Seed platform defaults once the Rust KV file is open.
  static Future<void> seedPlatformDefaultsAfterEngine() async {
    final profile = await detectProfile();
    SettingsService.configurePlatformProfile(profile);
    await SettingsService().ensurePlatformDefaultsSeeded(profile);
  }

  /// Android TV only — software WebView warm-up before first real WebView use.
  static Future<void> prepareWebViewForTv() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('prepareWebViewForTv');
    } catch (e) {
      debugPrint('[PlatformChannel] prepareWebViewForTv failed: $e');
    }
  }
}
