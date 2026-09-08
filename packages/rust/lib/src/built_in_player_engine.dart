import 'platform_profile.dart';

/// Where a built-in engine choice applies. Each surface remembers its own
/// ExoPlayer / MediaKit pick — changing IPTV does not change VOD, etc.
enum BuiltInPlayerContext {
  /// Home/Search + IPTV Movies/Series + Settings → Movies & series engine.
  vod('built_in_player_engine'),
  /// IPTV Live channels + Settings → IPTV engine.
  iptv('built_in_player_engine_iptv'),
  /// Live Matches native player (in-player menu only).
  live('built_in_player_engine_live');

  const BuiltInPlayerContext(this.storageKey);
  final String storageKey;
}

/// Built-in decoder when Settings → Video Player is "Built-in Player".
enum BuiltInPlayerEngine {
  mediaKit('mediakit'),
  exoPlayer('exoplayer');

  const BuiltInPlayerEngine(this.storageKey);
  final String storageKey;

  static BuiltInPlayerEngine fromStorage(String? raw) {
    if (raw == mediaKit.storageKey) return mediaKit;
    if (raw == exoPlayer.storageKey) return exoPlayer;
    return forPlatformProfile(PlatformProfile.phone);
  }

  /// Android phone/TV → ExoPlayer. Desktop → MediaKit.
  static BuiltInPlayerEngine forPlatformProfile(PlatformProfile profile) {
    return switch (profile) {
      PlatformProfile.desktop => mediaKit,
      PlatformProfile.phone || PlatformProfile.androidTv => exoPlayer,
    };
  }

  /// Early UI paint before profile/settings hydrate (Android-biased).
  static BuiltInPlayerEngine platformDefault() => exoPlayer;

  /// Per-surface default when no KV value exists.
  static BuiltInPlayerEngine defaultForContext(
    BuiltInPlayerContext context, {
    PlatformProfile profile = PlatformProfile.phone,
  }) {
    return forPlatformProfile(profile);
  }

  String get displayName => switch (this) {
        BuiltInPlayerEngine.mediaKit => 'MediaKit (libmpv)',
        BuiltInPlayerEngine.exoPlayer => 'ExoPlayer (Media3)',
      };
}

/// Enum declaration order. Prefer [builtInPlayerEngineOptionsForUi] in pickers.
const builtInPlayerEngineOptions = BuiltInPlayerEngine.values;

/// UI order: ExoPlayer (Android default) first, then MediaKit.
List<BuiltInPlayerEngine> get builtInPlayerEngineOptionsForUi {
  return const [
    BuiltInPlayerEngine.exoPlayer,
    BuiltInPlayerEngine.mediaKit,
  ];
}
