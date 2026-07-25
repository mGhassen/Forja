import 'dart:io';

import 'package:rust/src/engine.dart';

Future<void> initRustForAppTests() async {
  if (RustLib.isInitialized) return;
  final path = _resolveRustLibPath();
  if (!File(path).existsSync()) {
    throw StateError(
      'Rust dylib not found at $path - run ./scripts/build_rust.sh first',
    );
  }
  await RustLib.init(libraryPath: path);
}

String _resolveRustLibPath() {
  final name = Platform.isMacOS
      ? 'libffi.dylib'
      : Platform.isLinux
          ? 'libffi.so'
          : 'ffi.dll';
  var dir = Directory.current;
  for (var i = 0; i < 8; i++) {
    final candidate = '${dir.path}/crates/target/release/$name';
    if (File(candidate).existsSync()) return candidate;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('Could not locate Rust dylib - run ./scripts/build_rust.sh');
}
