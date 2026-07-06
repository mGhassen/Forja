import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

import '../helpers/rust_engine.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('runRustIsolate calls FFI off the test isolate', () async {
    final version = await runRustIsolate(() => RustLib.instance.version);
    expect(version, isNotEmpty);
  });
}
