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
    expect(BuiltInPlayerEngine.fromStorage('vlc'), BuiltInPlayerEngine.vlc);
    expect(BuiltInPlayerEngine.fromStorage(null), BuiltInPlayerEngine.mediaKit);
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
    expect(ui.first, BuiltInPlayerEngine.mediaKit);
  });

  test('defaultForContext: all profiles/surfaces default to MediaKit', () {
    for (final profile in PlatformProfile.values) {
      for (final context in BuiltInPlayerContext.values) {
        expect(
          BuiltInPlayerEngine.defaultForContext(context, profile: profile),
          BuiltInPlayerEngine.mediaKit,
        );
      }
    }
  });

  test('preferredIptvHlsEngine is MediaKit', () {
    expect(preferredIptvHlsEngine(), BuiltInPlayerEngine.mediaKit);
  });
}
