import 'dart:async';
import 'dart:isolate';

import 'engine.dart';
import 'library_path.dart';

/// Runs sync Rust FFI on a worker isolate so the UI isolate stays responsive.
Future<T> runRustIsolate<T>(
  FutureOr<T> Function() fn, {
  String? libraryPath,
}) {
  final path = libraryPath ??
      RustLib.loadedLibraryPath ??
      firstExistingRustLibrary();
  if (path == null) {
    return Future.error(
      StateError(
        'Rust library path unknown — call Engine.init() on the main isolate first',
      ),
    );
  }
  return Isolate.run(() async {
    RustLib.initSync(path);
    return fn();
  });
}

Future<String> runWebstreamrGetStreamsJson(String requestJson) =>
    runRustIsolate(
      () => RustLib.instance.webstreamrGetStreamsJson(requestJson),
    );
