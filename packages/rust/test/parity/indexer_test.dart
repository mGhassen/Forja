import '../helpers/rust_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('indexerRequestJson rejects unknown action', () {
    final raw = RustLib.instance.indexerRequestJson('{"action":"nope"}');
    expect(raw, contains('unknown action'));
  });

  test('indexerRequestJson rejects invalid json', () {
    final raw = RustLib.instance.indexerRequestJson('{');
    expect(raw, contains('invalid request'));
  });
}
