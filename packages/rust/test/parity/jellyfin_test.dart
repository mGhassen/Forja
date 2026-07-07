import 'dart:convert';

import '../helpers/rust_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('jellyfinRequestJson rejects empty base_url', () {
    final raw = RustLib.instance.jellyfinRequestJson(
      jsonEncode({
        'base_url': '',
        'method': 'GET',
        'path': '/Users/Me',
        'authorization': 'MediaBrowser Client="Forja"',
      }),
    );
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    expect(decoded['error'], isNotNull);
  });

  test('jellyfinRequestJson rejects unsupported method', () {
    final raw = RustLib.instance.jellyfinRequestJson(
      jsonEncode({
        'base_url': 'https://example.com',
        'method': 'PATCH',
        'path': '/Users/Me',
        'authorization': 'MediaBrowser Client="Forja"',
      }),
    );
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    expect(decoded['error'], isNotNull);
  });
}
