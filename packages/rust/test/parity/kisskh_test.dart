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

  test('kisskhCatalogJson probe_one rejects unknown mirrors', () {
    final rejected = jsonDecode(
      RustLib.instance.kisskhCatalogJson(
        '{"action":"probe_one","base_url":"https://kisskh.buzz"}',
      ),
    ) as Map<String, dynamic>;
    expect(rejected['error'], contains('Unsupported KissKh mirror'));
  });

  test('kisskhCatalogJson probe_mirrors returns mirror rows', () {
    final raw = RustLib.instance.kisskhCatalogJson('{"action":"probe_mirrors"}');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    expect(map.containsKey('error'), isFalse);
    final mirrors = map['mirrors'] as List<dynamic>;
    expect(mirrors.length, 5);
    for (final row in mirrors) {
      expect(row, isA<Map>());
      final m = Map<String, dynamic>.from(row as Map);
      expect(m['base_url'], startsWith('https://kisskh.'));
      expect(m.containsKey('healthy'), isTrue);
    }
  });

  test('kisskhCatalogJson activates only verified mirrors', () {
    final activated =
        jsonDecode(
              RustLib.instance.kisskhCatalogJson(
                '{"action":"activate_base_url","base_url":"https://kisskh.nl"}',
              ),
            )
            as Map<String, dynamic>;
    expect(activated['base_url'], 'https://kisskh.nl');

    final rejected =
        jsonDecode(
              RustLib.instance.kisskhCatalogJson(
                '{"action":"activate_base_url","base_url":"https://kisskh.buzz"}',
              ),
            )
            as Map<String, dynamic>;
    expect(rejected['error'], contains('Unsupported KissKh mirror'));
  });

  test('kisskhCatalogJson enrich_cards empty', () async {
    final decoded = await kisskhCatalog({
      'action': 'enrich_cards',
      'cards_json': '[]',
    });
    expect(decoded['cards'], isEmpty);
  });
}
