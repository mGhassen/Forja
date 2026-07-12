import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:rust/rust.dart';

/// Probes device codec capabilities (host-side per ENGINE_BOUNDARY C6).
abstract final class DeviceCapabilitiesService {
  static const _channel = MethodChannel('forja/platform');
  static DevicePlaybackCapabilities? _hardwareCached;

  static Future<DevicePlaybackCapabilities> detect({
    PlatformProfile? platformProfile,
  }) async {
    final profile = platformProfile ?? SettingsService.platformProfile;
    final hardware = _hardwareCached ??= await _probeHardware(profile);
    final userMax = await SettingsService().getMaxPlaybackHeight();
    return DevicePlaybackCapabilities(
      maxHeight: hardware.maxHeight,
      hevc: hardware.hevc,
      av1: hardware.av1,
      vp9: hardware.vp9,
      hdr10: hardware.hdr10,
      dolbyVision: hardware.dolbyVision,
      isLowPower: hardware.isLowPower,
      softwareDecodeAllowed: hardware.softwareDecodeAllowed,
      userMaxHeight: userMax,
    );
  }

  static Future<DevicePlaybackCapabilities> _probeHardware(
    PlatformProfile profile,
  ) async {
    if (Platform.isAndroid) {
      try {
        final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
          'getPlaybackCapabilities',
        );
        if (raw != null) {
          final map = raw.map(
            (k, v) => MapEntry(k.toString(), v),
          );
          var caps = DevicePlaybackCapabilities.fromJson(
            Map<String, dynamic>.from(map),
          );
          if (profile == PlatformProfile.androidTv) {
            caps = DevicePlaybackCapabilities(
              maxHeight: 1080,
              hevc: caps.hevc,
              av1: caps.av1,
              vp9: caps.vp9,
              hdr10: false,
              dolbyVision: false,
              isLowPower: true,
              softwareDecodeAllowed: false,
            );
          }
          return caps;
        }
      } catch (e) {
        debugPrint('[DeviceCapabilities] Android probe failed: $e');
      }
    }

    if (profile == PlatformProfile.androidTv) {
      return DevicePlaybackCapabilities.constrained;
    }

    if (kIsWeb) {
      return DevicePlaybackCapabilities.constrained;
    }

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return DevicePlaybackCapabilities.desktop;
    }

    return DevicePlaybackCapabilities.desktop;
  }

  @visibleForTesting
  static void clearCache() => _hardwareCached = null;
}
