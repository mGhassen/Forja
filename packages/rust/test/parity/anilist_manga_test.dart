import 'dart:convert';

import '../helpers/rust_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('anilistQueryJson fetches trending', () async {
    const q =
        'query { Page(page: 1, perPage: 1) { media(sort: TRENDING_DESC, type: ANIME) { id } } }';
    final raw = RustLib.instance.anilistQueryJson(q);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    expect(decoded['data'], isNotNull);
  });

  test('mangaFetchHtml rejects invalid url', () {
    final raw = RustLib.instance.mangaFetchHtml('not-a-url');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    expect(decoded['error'], isNotNull);
  });
}
