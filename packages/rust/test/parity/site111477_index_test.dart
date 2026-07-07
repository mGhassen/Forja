import '../helpers/rust_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('site111477IndexRequestJson rejects unknown action', () {
    final raw = RustLib.instance.site111477IndexRequestJson('{"action":"nope"}');
    expect(raw, contains('unknown action'));
  });
}
