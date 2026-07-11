import 'dart:io';

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

  /// Android defaults to ExoPlayer; all other platforms to media_kit.
  static BuiltInPlayerEngine platformDefault() {
    if (Platform.isAndroid) return exoPlayer;
    return mediaKit;
  }

  String get displayName => switch (this) {
        BuiltInPlayerEngine.mediaKit => 'MediaKit (libmpv)',
        BuiltInPlayerEngine.exoPlayer => 'ExoPlayer (Media3)',
      };
}

const builtInPlayerEngineOptions = BuiltInPlayerEngine.values;
