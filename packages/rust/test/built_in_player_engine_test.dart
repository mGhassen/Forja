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
      BuiltInPlayerEngine.fromStorage('avplayer'),
      BuiltInPlayerEngine.avPlayer,
    );
    expect(
      BuiltInPlayerEngine.fromStorage('vlc'),
      BuiltInPlayerEngine.vlc,
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

  test('UI options always include MediaKit', () {
    final ui = builtInPlayerEngineOptionsForUi;
    expect(ui, isNotEmpty);
    expect(ui, contains(BuiltInPlayerEngine.mediaKit));
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

  test('defaultForContext: desktop vod/live MediaKit', () {
    expect(
      BuiltInPlayerEngine.defaultForContext(
        BuiltInPlayerContext.vod,
        profile: PlatformProfile.desktop,
      ),
      BuiltInPlayerEngine.mediaKit,
    );
    expect(
      BuiltInPlayerEngine.defaultForContext(
        BuiltInPlayerContext.live,
        profile: PlatformProfile.desktop,
      ),
      BuiltInPlayerEngine.mediaKit,
    );
  });

  test('preferredIptvHlsEngine is platform-shaped', () {
    final preferred = preferredIptvHlsEngine();
    expect(
      preferred,
      anyOf(
        BuiltInPlayerEngine.exoPlayer,
        BuiltInPlayerEngine.avPlayer,
        BuiltInPlayerEngine.vlc,
        BuiltInPlayerEngine.mediaKit,
      ),
    );
  });
}
