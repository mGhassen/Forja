import 'dart:convert';

import '../helpers/rust_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('traktRequestJson rejects empty client_id', () {
    final raw = RustLib.instance.traktRequestJson(
      jsonEncode({'client_id': '', 'method': 'GET', 'path': '/users/me'}),
    );
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    expect(decoded['error'], isNotNull);
  });

  test('traktRequestJson rejects unsupported method', () {
    final raw = RustLib.instance.traktRequestJson(
      jsonEncode({
        'client_id': 'test',
        'method': 'PATCH',
        'path': '/users/me',
        'access_token': 'token',
      }),
    );
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    expect(decoded['error'], isNotNull);
  });
}
