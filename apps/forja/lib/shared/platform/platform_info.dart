import 'package:rust/rust.dart';

/// Read-only host access to the boot-time platform profile.
abstract final class PlatformInfo {
  static PlatformProfile get profile => SettingsService.platformProfile;

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
