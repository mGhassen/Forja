import 'dart:convert';

import '../helpers/rust_engine.dart';
import 'package:rust/rust.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('liveMatchesFetchJson rejects unknown action', () {
    final raw = RustLib.instance.liveMatchesFetchJson(
      jsonEncode({'action': 'nope'}),
    );
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    expect(parsed['error'], isNotNull);
  });

  test('liveMatchesFetchJson streamed_streams requires params', () {
    final raw = RustLib.instance.liveMatchesFetchJson(
      jsonEncode({'action': 'streamed_streams'}),
    );
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    expect(parsed['error'], contains('source and id required'));
  });

  test('iptvRedditCatalogJson rejects unknown action', () {
    final raw = RustLib.instance.iptvRedditCatalogJson(
      jsonEncode({'action': 'nope'}),
    );
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    expect(parsed['error'], isNotNull);
  });

  test('iptvRedditCatalogJson oauth_listing requires sub', () {
    final raw = RustLib.instance.iptvRedditCatalogJson(
      jsonEncode({'action': 'oauth_listing'}),
    );
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    expect(parsed['error'], contains('sub required'));
  });
}
