import 'dart:io';

import 'package:path/path.dart' as p;

/// macOS `.app` bundles run sandboxed and cannot dlopen repo `crates/target/…`.
bool runningInAppBundle([String? resolvedExecutable]) {
  return (resolvedExecutable ?? Platform.resolvedExecutable)
      .contains('.app/Contents/MacOS/');
}

/// Resolves `libffi` for dev (`flutter run`) and packaged app builds.
List<String> rustLibraryCandidates() =>
    rustLibraryCandidatesFor(resolvedExecutable: Platform.resolvedExecutable);

List<String> rustLibraryCandidatesFor({required String resolvedExecutable}) {
  const name = 'ffi';
  final seen = <String>{};
  final candidates = <String>[];

  void add(String path) {
    if (path.isEmpty || !seen.add(path)) return;
    candidates.add(path);
  }

  final env = Platform.environment['RUST_LIB'];
  if (env != null && env.isNotEmpty) {
    add(env);
  }

  if (Platform.isAndroid) {
    add('lib$name.so');
  } else if (Platform.isIOS) {
    add('lib$name.dylib');
    final frameworks = File(resolvedExecutable).parent.path;
    add('$frameworks/lib$name.dylib');
    add('$frameworks/Frameworks/lib$name.dylib');
  } else if (Platform.isMacOS) {
    final macosDir = File(resolvedExecutable).parent;
    final inBundle = runningInAppBundle(resolvedExecutable);

    if (inBundle) {
      add(p.normalize('${macosDir.path}/../Frameworks/lib$name.dylib'));
      add('lib$name.dylib');
    } else {
      final discovered = _discoverRepoDylib(resolvedExecutable);
      if (discovered != null) add(discovered);
      add('lib$name.dylib');
      add(p.normalize('${macosDir.path}/../Frameworks/lib$name.dylib'));
      add('${macosDir.path}/lib$name.dylib');
      add(
        '${macosDir.path}/../../../../../../macos/Runner/Frameworks/lib$name.dylib',
      );
    }
  } else if (Platform.isLinux) {
    add('lib$name.so');
    final dir = File(resolvedExecutable).parent.path;
    add('$dir/lib/lib$name.so');
    add('$dir/lib$name.so');
  } else if (Platform.isWindows) {
    add('$name.dll');
    add('${File(resolvedExecutable).parent.path}/$name.dll');
  }

  if (Platform.isMacOS && !runningInAppBundle(resolvedExecutable)) {
    for (final path in const [
      'crates/target/release/libffi.dylib',
      '../../crates/target/release/libffi.dylib',
      '../../../crates/target/release/libffi.dylib',
    ]) {
      add(path);
    }
  } else if (Platform.isLinux) {
    for (final path in const [
      'crates/target/release/libffi.so',
      '../../crates/target/release/libffi.so',
    ]) {
      add(path);
    }
  } else if (Platform.isWindows) {
    for (final path in const [
      'crates/target/release/ffi.dll',
      '../../crates/target/release/ffi.dll',
    ]) {
      add(path);
    }
  } else if (Platform.isAndroid) {
    for (final path in const [
      'crates/target/aarch64-linux-android/release/libffi.so',
      '../../crates/target/aarch64-linux-android/release/libffi.so',
    ]) {
      add(path);
    }
  } else if (Platform.isIOS) {
    for (final path in const [
      'crates/target/aarch64-apple-ios/release/libffi.dylib',
      '../../crates/target/aarch64-apple-ios/release/libffi.dylib',
    ]) {
      add(path);
    }
  }

  return candidates;
}

String? _discoverRepoDylib(String resolvedExecutable) {
  final lib = Platform.isMacOS || Platform.isIOS
      ? 'libffi.dylib'
      : Platform.isLinux || Platform.isAndroid
          ? 'libffi.so'
          : Platform.isWindows
              ? 'ffi.dll'
              : null;
  if (lib == null) return null;

  var dir = File(resolvedExecutable).parent;
  for (var i = 0; i < 12; i++) {
    if (runningInAppBundle(resolvedExecutable)) break;

    final candidate = '${dir.path}/crates/target/release/$lib';
    if (File(candidate).existsSync()) return candidate;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return null;
}

String? firstExistingRustLibrary() {
  for (final path in rustLibraryCandidates()) {
    if (_candidateExists(path)) return path;
  }
  return null;
}

bool _candidateExists(String path) {
  if (path.contains('..') || path.startsWith('/') || path.contains(':\\')) {
    return File(path).existsSync();
  }
  return File(path).existsSync();
}
