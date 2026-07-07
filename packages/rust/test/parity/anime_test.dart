import 'dart:convert';

import '../helpers/rust_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('animeRequestJson rejects empty url', () {
    final raw = RustLib.instance.animeRequestJson(
      jsonEncode({'url': '', 'method': 'GET'}),
    );
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    expect(decoded['error'], isNotNull);
  });

  test('animeRequestJson rejects unsupported method', () {
    final raw = RustLib.instance.animeRequestJson(
      jsonEncode({'url': 'https://example.com', 'method': 'PATCH'}),
    );
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    expect(decoded['error'], isNotNull);
  });
}
