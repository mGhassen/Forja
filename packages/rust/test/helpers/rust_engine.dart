import 'dart:io';

import 'package:rust/rust.dart';

/// Resolves the release dylib built by `./scripts/build_rust.sh`.
Future<void> initRustForTests() async {
  if (RustLib.isInitialized) return;
  final path = resolveRustLibPath();
  if (!File(path).existsSync()) {
    throw StateError(
      'Rust dylib not found at $path — run ./scripts/build_rust.sh first',
    );
  }
  await RustLib.init(libraryPath: path);
  await EngineWorkerPool.start(path);
}

String resolveRustLibPath() {
  final discovered = _discoverRepoDylib();
  if (discovered != null) return discovered;

  final root = _findRepoRoot();
  if (Platform.isMacOS) {
    return '$root/crates/target/release/libffi.dylib';
  }
  if (Platform.isLinux) {
    return '$root/crates/target/release/libffi.so';
  }
  if (Platform.isWindows) {
    return '$root/crates/target/release/ffi.dll';
  }
  throw UnsupportedError('Rust tests run on desktop only');
}

String? _discoverRepoDylib() {
  final name = Platform.isMacOS
      ? 'libffi.dylib'
      : Platform.isLinux
          ? 'libffi.so'
          : 'ffi.dll';
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 12; i++) {
    final candidate = '${dir.path}/crates/target/release/$name';
    if (File(candidate).existsSync()) return candidate;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return null;
}

String _findRepoRoot() {
  final starts = <Directory>[Directory.current];
  final script = Platform.script;
  if (script.scheme == 'file') {
    starts.add(Directory(File.fromUri(script).parent.path));
  }
  for (final start in starts) {
    var dir = start;
    for (var i = 0; i < 8; i++) {
      if (Directory('${dir.path}/crates/ffi').existsSync()) {
        return dir.path;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
  }
  return Directory.current.path;
}
