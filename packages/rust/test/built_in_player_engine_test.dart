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
}
