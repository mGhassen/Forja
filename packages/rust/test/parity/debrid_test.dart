import '../helpers/rust_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('debridRequestJson rejects unknown action', () {
    final raw = RustLib.instance.debridRequestJson('{"action":"nope"}');
    expect(raw, contains('unknown action'));
  });

  test('debridRequestJson rejects unknown service', () {
    final raw = RustLib.instance.debridRequestJson(
      '{"action":"resolve","service":"Nope","api_key":"x","magnet":"magnet:?"}',
    );
    expect(raw, contains('Unknown debrid service'));
  });
}
