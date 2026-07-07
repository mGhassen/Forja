import 'dart:convert';

import '../helpers/rust_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('megaResolveJson rejects unparseable embed', () {
    final raw = RustLib.instance.megaResolveJson('https://example.com/not-mega');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    expect(map['error'], isNotNull);
    expect(map['url'], isNull);
  });
}
