import 'dart:io';

/// Where a built-in engine choice applies. Each surface remembers its own
/// ExoPlayer / MediaKit pick — changing IPTV does not change VOD, etc.
enum BuiltInPlayerContext {
  /// Movies / series + Settings → Playback → Built-in engine.
  vod('built_in_player_engine'),
  iptv('built_in_player_engine_iptv'),
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
    if (raw == exoPlayer.storageKey) return exoPlayer;
    return mediaKit;
  }

  /// Android (phone + TV) defaults to ExoPlayer; all other platforms to media_kit.
  static BuiltInPlayerEngine platformDefault() {
    if (Platform.isAndroid) return exoPlayer;
    return mediaKit;
  }

  /// Per-surface default when no KV value exists (and legacy VOD fallback does not apply).
  /// Live Matches → MediaKit.
  static BuiltInPlayerEngine defaultForContext(BuiltInPlayerContext context) {
    if (context == BuiltInPlayerContext.live) return mediaKit;
    return platformDefault();
  }

  String get displayName => switch (this) {
        BuiltInPlayerEngine.mediaKit => 'MediaKit (libmpv)',
        BuiltInPlayerEngine.exoPlayer => 'ExoPlayer (Media3)',
      };
}

/// Enum declaration order (MediaKit first). Prefer [builtInPlayerEngineOptionsForUi]
/// in pickers so ExoPlayer (the Android default) appears first.
const builtInPlayerEngineOptions = BuiltInPlayerEngine.values;

/// UI order: ExoPlayer first on Android (default), then MediaKit.
List<BuiltInPlayerEngine> get builtInPlayerEngineOptionsForUi {
  if (Platform.isAndroid) {
    return const [
      BuiltInPlayerEngine.exoPlayer,
      BuiltInPlayerEngine.mediaKit,
    ];
  }
  return builtInPlayerEngineOptions;
}
