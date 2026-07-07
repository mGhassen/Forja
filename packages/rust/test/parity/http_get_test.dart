import 'dart:convert';

import '../helpers/rust_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('httpGetJson rejects invalid URL', () {
    final raw = RustLib.instance.httpGetJson('not-a-url');
    final m = jsonDecode(raw) as Map<String, dynamic>;
    expect(m['error'], isNotNull);
  });

  test('httpGetJson passes User-Agent header', () async {
    final raw = RustLib.instance.httpGetJson(
      'https://httpbin.org/headers',
      timeoutSecs: 15,
      headersJson: jsonEncode({
        'User-Agent': 'VLC/3.0.20 LibVLC/3.0.20',
      }),
    );
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    if (parsed.containsKey('error') || parsed['status'] != 200) {
      // httpbin is flaky — local invalid-url test covers FFI wiring.
      return;
    }
    final body = jsonDecode(parsed['body'] as String) as Map<String, dynamic>;
    final headers = body['headers'] as Map<String, dynamic>;
    expect(headers['User-Agent'], contains('VLC'));
  });

  test('httpPostJson rejects invalid URL', () {
    final raw = RustLib.instance.httpPostJson('not-a-url', body: 'a=1');
    final m = jsonDecode(raw) as Map<String, dynamic>;
    expect(m['error'], isNotNull);
  });
}
