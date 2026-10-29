import 'package:forja/shared/platform/android_form_factor.dart';
import 'package:rust/rust.dart';

/// Read-only host access to the boot-time platform profile.
abstract final class PlatformInfo {
  static PlatformProfile get profile => SettingsService.platformProfile;

  /// Set at [PlatformChannel.initialize] from the Android build flavor.
  static AndroidFormFactor androidFormFactor = AndroidFormFactor.tv;

  /// Set at [PlatformChannel.initialize] — native leanback / TV ui mode only,
  /// without the panel-size fallback. Hardware truth for the updater.
  static bool nativeAndroidTv = false;

  /// Set at [PlatformChannel.initialize] — native FEATURE_TOUCHSCREEN. TV boxes
  /// without leanback still report false here.
  static bool nativeTouchscreen = false;

  static bool get isAndroidTv => profile == PlatformProfile.androidTv;

  /// Offline Downloads (Settings, details, Sources, player). Android TV has none.
  static bool get offlineDownloadsEnabled => !isAndroidTv;

  static bool get isDesktop => profile == PlatformProfile.desktop;

  static bool get isPhone => profile == PlatformProfile.phone;

  /// Set at [PlatformChannel.initialize] — goldfish/ranchu leanback emulators.
  /// Exo: TextureView + TLHC on emulator (issue 108 T10).
  static bool isAndroidEmulator = false;

  /// Pack manifest platform id for this device (`platforms` field).
  static String get packPlatformId => packPlatformIdFor(profile);

  /// Manifest `platforms` vocabulary: `desktop` · `phone` · `tv`.
  static String packPlatformIdFor(PlatformProfile p) => switch (p) {
        PlatformProfile.desktop => 'desktop',
        PlatformProfile.phone => 'phone',
        PlatformProfile.androidTv => 'tv',
      };

  /// True when a plugin with this manifest `platforms` list may run here.
  /// Empty → every platform.
  static bool supportsPlugin({required List<String> platforms}) =>
      platforms.isEmpty || platforms.contains(packPlatformId);
}
