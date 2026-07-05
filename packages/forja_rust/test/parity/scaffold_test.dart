import '../helpers/rust_engine.dart';
import 'package:forja_rust/forja_rust.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('FFI round-trip add', () {
    expect(ForjaRust.instance.add(2, 2), 4);
  });

  test('version string is non-empty', () {
    expect(ForjaRust.instance.version, isNotEmpty);
  });
}
