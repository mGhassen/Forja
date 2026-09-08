import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  test('fromStorage maps keys', () {
    expect(
      BuiltInPlayerEngine.fromStorage('exoplayer'),
      BuiltInPlayerEngine.exoPlayer,
    );
    expect(
      BuiltInPlayerEngine.fromStorage('mediakit'),
      BuiltInPlayerEngine.mediaKit,
    );
    expect(
      BuiltInPlayerEngine.fromStorage(null),
      BuiltInPlayerEngine.exoPlayer,
    );
  });

  test('displayName is stable for settings UI', () {
    for (final engine in builtInPlayerEngineOptions) {
      expect(engine.displayName, isNotEmpty);
    }
  });

  test('UI options list ExoPlayer first', () {
    final ui = builtInPlayerEngineOptionsForUi;
    expect(ui, isNotEmpty);
    expect(ui.first, BuiltInPlayerEngine.exoPlayer);
    expect(ui.toSet(), builtInPlayerEngineOptions.toSet());
  });

  test('defaultForContext: Android live/vod/iptv default to Exo', () {
    for (final profile in [
      PlatformProfile.phone,
      PlatformProfile.androidTv,
    ]) {
      expect(
        BuiltInPlayerEngine.defaultForContext(
          BuiltInPlayerContext.live,
          profile: profile,
        ),
        BuiltInPlayerEngine.exoPlayer,
      );
      expect(
        BuiltInPlayerEngine.defaultForContext(
          BuiltInPlayerContext.vod,
          profile: profile,
        ),
        BuiltInPlayerEngine.exoPlayer,
      );
      expect(
        BuiltInPlayerEngine.defaultForContext(
          BuiltInPlayerContext.iptv,
          profile: profile,
        ),
        BuiltInPlayerEngine.exoPlayer,
      );
    }
  });

  test('defaultForContext: desktop stays MediaKit', () {
    expect(
      BuiltInPlayerEngine.defaultForContext(
        BuiltInPlayerContext.vod,
        profile: PlatformProfile.desktop,
      ),
      BuiltInPlayerEngine.mediaKit,
    );
  });

  test('player contexts use distinct storage keys', () {
    expect(
      BuiltInPlayerContext.vod.storageKey,
      'built_in_player_engine',
    );
    expect(
      BuiltInPlayerContext.iptv.storageKey,
      'built_in_player_engine_iptv',
    );
    expect(
      BuiltInPlayerContext.live.storageKey,
      'built_in_player_engine_live',
    );
    expect(
      {
        for (final c in BuiltInPlayerContext.values) c.storageKey,
      }.length,
      BuiltInPlayerContext.values.length,
    );
  });
}
