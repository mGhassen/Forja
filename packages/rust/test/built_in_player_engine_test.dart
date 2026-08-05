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
      BuiltInPlayerEngine.mediaKit,
    );
  });

  test('displayName is stable for settings UI', () {
    for (final engine in builtInPlayerEngineOptions) {
      expect(engine.displayName, isNotEmpty);
    }
  });

  test('UI options list ExoPlayer first on Android', () {
    final ui = builtInPlayerEngineOptionsForUi;
    expect(ui, isNotEmpty);
    // VM tests run as non-Android host → declaration order.
    // On device Android the getter returns [exoPlayer, mediaKit].
    expect(ui.toSet(), builtInPlayerEngineOptions.toSet());
  });

  test('defaultForContext: live is MediaKit; vod/iptv follow platform', () {
    expect(
      BuiltInPlayerEngine.defaultForContext(BuiltInPlayerContext.live),
      BuiltInPlayerEngine.mediaKit,
    );
    expect(
      BuiltInPlayerEngine.defaultForContext(BuiltInPlayerContext.vod),
      BuiltInPlayerEngine.platformDefault(),
    );
    expect(
      BuiltInPlayerEngine.defaultForContext(BuiltInPlayerContext.iptv),
      BuiltInPlayerEngine.platformDefault(),
    );
  });

  // ATV IPTV MediaKit default is asserted in settings_service_platform_defaults_test
  // (getBuiltInPlayerEngine — unset IPTV must not inherit VOD Exo).

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
