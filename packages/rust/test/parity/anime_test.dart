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

  test('animeExtractorJson rejects unknown action', () {
    final raw = RustLib.instance.animeExtractorJson('{"action":"nope"}');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    expect(decoded['error'], isNotNull);
  });

  test('animeExtractorJson returns allanime providers', () {
    final raw = RustLib.instance.animeExtractorJson(
      '{"action":"allanime_known_providers"}',
    );
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    expect(decoded['providers'], contains('Default'));
  });

  test('animeExtractorJson probe_stream_url empty returns false', () {
    final raw = RustLib.instance.animeExtractorJson(
      '{"action":"probe_stream_url","url":"","headers":{}}',
    );
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    expect(decoded['reachable'], isFalse);
  });
}
