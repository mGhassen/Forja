import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'platform_profile.dart';

/// Where a built-in engine choice applies. Each surface remembers its own
/// pick — changing IPTV does not change VOD, etc.
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
  exoPlayer('exoplayer'),
  avPlayer('avplayer'),
  vlc('vlc');

  const BuiltInPlayerEngine(this.storageKey);
  final String storageKey;

  static BuiltInPlayerEngine fromStorage(String? raw) {
    if (raw == mediaKit.storageKey) return mediaKit;
    if (raw == exoPlayer.storageKey) return exoPlayer;
    if (raw == avPlayer.storageKey) return avPlayer;
    if (raw == vlc.storageKey) return vlc;
    return forPlatformProfile(PlatformProfile.phone);
  }

  /// All profiles → MediaKit (Exo / AVPlayer / VLC stay selectable where available).
  static BuiltInPlayerEngine forPlatformProfile(PlatformProfile _) => mediaKit;

  /// Early UI paint before profile/settings hydrate.
  static BuiltInPlayerEngine platformDefault() => mediaKit;

  /// Per-surface default when no KV value exists.
  static BuiltInPlayerEngine defaultForContext(
    BuiltInPlayerContext _, {
    PlatformProfile profile = PlatformProfile.phone,
  }) {
    return forPlatformProfile(profile);
  }

  String get displayName => switch (this) {
    BuiltInPlayerEngine.mediaKit => 'MediaKit (libmpv)',
    BuiltInPlayerEngine.exoPlayer => 'ExoPlayer (Media3)',
    BuiltInPlayerEngine.avPlayer => 'AVPlayer',
    BuiltInPlayerEngine.vlc => 'VLC (libVLC)',
  };

  /// Whether this engine can run on the current OS (compile-time platforms).
  bool get isAvailableOnCurrentPlatform {
    if (kIsWeb) return this == mediaKit;
    return switch (this) {
      BuiltInPlayerEngine.mediaKit => true,
      BuiltInPlayerEngine.exoPlayer => Platform.isAndroid,
      BuiltInPlayerEngine.avPlayer => Platform.isMacOS,
      BuiltInPlayerEngine.vlc =>
        Platform.isWindows || Platform.isMacOS || Platform.isLinux,
    };
  }
}

/// Enum declaration order. Prefer [builtInPlayerEngineOptionsForUi] in pickers.
const builtInPlayerEngineOptions = BuiltInPlayerEngine.values;

/// Platform-gated UI order for Settings / in-player Player menu.
///
/// Always includes [BuiltInPlayerEngine.mediaKit] when that engine is available
/// (never hide MediaKit as a "fix").
List<BuiltInPlayerEngine> get builtInPlayerEngineOptionsForUi {
  if (kIsWeb) {
    return const [BuiltInPlayerEngine.mediaKit];
  }
  if (Platform.isAndroid) {
    return const [BuiltInPlayerEngine.mediaKit, BuiltInPlayerEngine.exoPlayer];
  }
  if (Platform.isMacOS) {
    return const [
      BuiltInPlayerEngine.mediaKit,
      BuiltInPlayerEngine.avPlayer,
      BuiltInPlayerEngine.vlc,
    ];
  }
  if (Platform.isWindows || Platform.isLinux) {
    return const [BuiltInPlayerEngine.mediaKit, BuiltInPlayerEngine.vlc];
  }
  return const [BuiltInPlayerEngine.mediaKit];
}

/// Preferred IPTV live engine for an HLS URL on this OS (before availability
/// probes). Callers that have a saved engine must use that instead.
BuiltInPlayerEngine preferredIptvHlsEngine() {
  return BuiltInPlayerEngine.mediaKit;
}
