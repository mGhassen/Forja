import 'dart:convert';

import '../helpers/rust_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('musicRequestJson rejects unknown action', () {
    final raw = RustLib.instance.musicRequestJson('{"action":"nope"}');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    expect(map['error'], contains('unknown action'));
  });
}
