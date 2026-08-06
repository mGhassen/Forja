import 'package:rust/rust.dart';

/// Read-only host access to the boot-time platform profile.
abstract final class PlatformInfo {
  static PlatformProfile get profile => SettingsService.platformProfile;

  static bool get isAndroidTv => profile == PlatformProfile.androidTv;

  static bool get isDesktop => profile == PlatformProfile.desktop;

  static bool get isPhone => profile == PlatformProfile.phone;

  /// Set at [PlatformChannel.initialize] — goldfish/ranchu leanback emulators.
  /// Emulators force Exo TextureView and MediaKit software decode (goldfish
  /// HEVC MediaCodec ANRs on 1080p). Home/VOD always TextureView; IPTV live
  /// may use SurfaceView until [ExoPlayerBridge.preferTextureSurface] flips.
  static bool isAndroidEmulator = false;
}
