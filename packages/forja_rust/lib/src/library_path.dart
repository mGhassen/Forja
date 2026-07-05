import 'dart:io';

/// Resolves `libforja_ffi` for dev (`flutter run`) and packaged app builds.
List<String> rustLibraryCandidates() {
  const name = 'forja_ffi';
  final candidates = <String>[];

  final discovered = _discoverRepoDylib();
  if (discovered != null) {
    candidates.add(discovered);
  }

  final env = Platform.environment['FORJA_RUST_LIB'];
  if (env != null && env.isNotEmpty) {
    candidates.insert(0, env);
  }

  if (Platform.isAndroid) {
    candidates.add('lib$name.so');
  } else if (Platform.isIOS) {
    candidates.add('lib$name.dylib');
    final exe = Platform.resolvedExecutable;
    final frameworks = File(exe).parent.path;
    candidates.add('$frameworks/lib$name.dylib');
    candidates.add('$frameworks/Frameworks/lib$name.dylib');
  } else if (Platform.isMacOS) {
    candidates.add('lib$name.dylib');
    final exe = Platform.resolvedExecutable;
    final macosDir = File(exe).parent;
    candidates.add('${macosDir.path}/../Frameworks/lib$name.dylib');
    candidates.add('${macosDir.path}/lib$name.dylib');
    candidates.add(
      '${macosDir.path}/../../../../../../macos/Runner/Frameworks/lib$name.dylib',
    );
  } else if (Platform.isLinux) {
    candidates.add('lib$name.so');
    final exe = Platform.resolvedExecutable;
    final dir = File(exe).parent.path;
    candidates.add('$dir/lib/lib$name.so');
    candidates.add('$dir/lib$name.so');
  } else if (Platform.isWindows) {
    candidates.add('$name.dll');
    final exe = Platform.resolvedExecutable;
    candidates.add('${File(exe).parent.path}/$name.dll');
  }

  if (Platform.isMacOS) {
    candidates.addAll(const [
      'crates/target/release/libforja_ffi.dylib',
      '../../crates/target/release/libforja_ffi.dylib',
      '../../../crates/target/release/libforja_ffi.dylib',
    ]);
  } else if (Platform.isLinux) {
    candidates.addAll(const [
      'crates/target/release/libforja_ffi.so',
      '../../crates/target/release/libforja_ffi.so',
    ]);
  } else if (Platform.isWindows) {
    candidates.addAll(const [
      'crates/target/release/forja_ffi.dll',
      '../../crates/target/release/forja_ffi.dll',
    ]);
  } else if (Platform.isAndroid) {
    candidates.addAll(const [
      'crates/target/aarch64-linux-android/release/libforja_ffi.so',
      '../../crates/target/aarch64-linux-android/release/libforja_ffi.so',
    ]);
  } else if (Platform.isIOS) {
    candidates.addAll(const [
      'crates/target/aarch64-apple-ios/release/libforja_ffi.dylib',
      '../../crates/target/aarch64-apple-ios/release/libforja_ffi.dylib',
    ]);
  }

  return candidates;
}

String? _discoverRepoDylib() {
  final lib = Platform.isMacOS || Platform.isIOS
      ? 'libforja_ffi.dylib'
      : Platform.isLinux || Platform.isAndroid
          ? 'libforja_ffi.so'
          : Platform.isWindows
              ? 'forja_ffi.dll'
              : null;
  if (lib == null) return null;

  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 12; i++) {
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
    if (path.contains('..') || path.startsWith('/') || path.contains(':\\')) {
      if (File(path).existsSync()) return path;
    } else if (File(path).existsSync()) {
      return path;
    }
  }
  return null;
}
