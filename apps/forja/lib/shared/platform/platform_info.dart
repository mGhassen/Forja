import 'package:rust/rust.dart';

/// Read-only host access to the boot-time platform profile.
abstract final class PlatformInfo {
  static PlatformProfile get profile => SettingsService.platformProfile;

  static bool get isAndroidTv => profile == PlatformProfile.androidTv;

  static bool get isDesktop => profile == PlatformProfile.desktop;

  static bool get isPhone => profile == PlatformProfile.phone;

  /// Set at [PlatformChannel.initialize] — goldfish/ranchu leanback emulators.
  /// Emulators force Exo TextureView; physical ATV uses SurfaceView unless
  /// [ExoPlayerBridge.preferTextureSurface] flips after audio-only failure.
  static bool isAndroidEmulator = false;
}
