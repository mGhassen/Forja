import 'dart:convert';

import '../helpers/rust_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('mangaCatalogJson rejects unknown action', () {
    final raw = RustLib.instance.mangaCatalogJson('{"action":"nope"}');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    expect(decoded['error'], isNotNull);
  });

  test('booksCatalogJson rejects unknown action', () {
    final raw = RustLib.instance.booksCatalogJson('{"action":"nope"}');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    expect(decoded['error'], isNotNull);
  });

  test('booksCatalogJson search empty query', () async {
    final decoded = await booksCatalog({'action': 'search', 'query': ''});
    expect(decoded['results'], isEmpty);
  });

  test('catalogCoreJson rejects unknown action', () {
    final raw = RustLib.instance.catalogCoreJson('{"action":"nope"}');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    expect(decoded['error'], isNotNull);
  });

  test('catalogCoreJson autocomplete empty', () async {
    final decoded = await catalogCore({'action': 'autocomplete', 'query': ''});
    expect(decoded['hits'], isEmpty);
  });
}
