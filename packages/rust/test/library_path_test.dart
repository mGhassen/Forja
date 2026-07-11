import 'package:flutter_test/flutter_test.dart';
import 'package:rust/src/library_path.dart';

void main() {
  const appExe =
      '/Users/dev/Forja/apps/forja/build/macos/Build/Products/Debug/forja.app/Contents/MacOS/forja';
  const dartExe = '/Users/dev/Forja/packages/rust/.dart_tool/pub/bin/test/test';

  test('runningInAppBundle detects sandboxed macOS app', () {
    expect(runningInAppBundle(appExe), isTrue);
    expect(runningInAppBundle(dartExe), isFalse);
  });

  test('macOS app bundle prefers embedded Frameworks dylib', () {
    final candidates = rustLibraryCandidatesFor(resolvedExecutable: appExe);

    expect(candidates.first, contains('Contents/Frameworks/libffi.dylib'));
    expect(
      candidates.any((path) => path.contains('/crates/target/release/')),
      isFalse,
    );
  });

  test('macOS dev host prefers repo dylib before relative fallbacks', () {
    final candidates = rustLibraryCandidatesFor(resolvedExecutable: dartExe);

    expect(candidates, contains('libffi.dylib'));
    expect(candidates, contains('crates/target/release/libffi.dylib'));
    expect(
      candidates.indexOf('libffi.dylib'),
      lessThan(candidates.indexOf('crates/target/release/libffi.dylib')),
    );
  });
}
