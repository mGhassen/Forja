import 'dart:convert';

import '../helpers/rust_engine.dart';
import 'package:rust/rust.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('openssl_aes_decrypt_json rejects invalid blob', () {
    final raw = RustLib.instance.opensslAesDecryptJson('not-valid-b64');
    final m = jsonDecode(raw) as Map<String, dynamic>;
    expect(m['error'], isNotNull);
  });
}
