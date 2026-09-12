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

  /// Android phone/TV → ExoPlayer. Desktop → MediaKit (OS-specific IPTV
  /// defaults live in [defaultForContext]).
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
    if (context == BuiltInPlayerContext.iptv &&
        profile == PlatformProfile.desktop &&
        !kIsWeb) {
      if (Platform.isMacOS) return avPlayer;
      if (Platform.isWindows) return vlc;
      if (Platform.isLinux) return vlc;
    }
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
    return const [
      BuiltInPlayerEngine.exoPlayer,
      BuiltInPlayerEngine.mediaKit,
    ];
  }
  if (Platform.isMacOS) {
    return const [
      BuiltInPlayerEngine.avPlayer,
      BuiltInPlayerEngine.mediaKit,
      BuiltInPlayerEngine.vlc,
    ];
  }
  if (Platform.isWindows || Platform.isLinux) {
    return const [
      BuiltInPlayerEngine.vlc,
      BuiltInPlayerEngine.mediaKit,
    ];
  }
  return const [BuiltInPlayerEngine.mediaKit];
}

/// Preferred IPTV live engine for an HLS URL on this OS (before availability
/// probes). Non-HLS progressive TS should stay on MediaKit.
BuiltInPlayerEngine preferredIptvHlsEngine() {
  if (kIsWeb) return BuiltInPlayerEngine.mediaKit;
  if (Platform.isAndroid) return BuiltInPlayerEngine.exoPlayer;
  if (Platform.isMacOS) return BuiltInPlayerEngine.avPlayer;
  if (Platform.isWindows || Platform.isLinux) return BuiltInPlayerEngine.vlc;
  return BuiltInPlayerEngine.mediaKit;
}
