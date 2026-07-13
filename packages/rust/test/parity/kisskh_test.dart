import 'dart:convert';

import '../helpers/rust_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('kisskhCatalogJson rejects unknown action', () {
    final raw = RustLib.instance.kisskhCatalogJson('{"action":"nope"}');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    expect(map['error'], contains('unknown action'));
  });

  test('kisskhCatalogJson slugify action', () {
    final raw = RustLib.instance.kisskhCatalogJson(
      '{"action":"slugify","title":"Hello World!"}',
    );
    final map = jsonDecode(raw) as Map<String, dynamic>;
    expect(map['slug'], 'hello-world');
  });

  test('kisskhCatalogJson episode_page_url action', () {
    final raw = RustLib.instance.kisskhCatalogJson(
      '{"action":"episode_page_url","id":9,"title":"My Drama","episode_id":42,"episode_number":3}',
    );
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final url = map['url'] as String;
    expect(url, contains('/Drama/my-drama/Episode-3?'));
    expect(url, contains('id=9'));
    expect(url, contains('ep=42'));
  });

  test('kisskhCatalogJson enrich_cards empty', () async {
    final decoded = await kisskhCatalog({
      'action': 'enrich_cards',
      'cards_json': '[]',
    });
    expect(decoded['cards'], isEmpty);
  });
}
