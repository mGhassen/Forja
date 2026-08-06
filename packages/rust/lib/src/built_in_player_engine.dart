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

  /// All platforms default to media_kit. ExoPlayer remains an Android option.
  static BuiltInPlayerEngine platformDefault() => mediaKit;

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
/// in pickers so the default engine appears first.
const builtInPlayerEngineOptions = BuiltInPlayerEngine.values;

/// UI order: MediaKit (default) first, then ExoPlayer on Android.
List<BuiltInPlayerEngine> get builtInPlayerEngineOptionsForUi {
  return builtInPlayerEngineOptions;
}
