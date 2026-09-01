import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/catalog/kit/chrome/catalog_pack_filters.dart';
import 'package:forja/shared/catalog/kit/details/catalog_play_filters.dart';

void main() {
  group('catalog play filters', () {
    tearDown(CatalogPackFiltersRegistry.clearForTest);

    test('parses pack filters.play grouped audio', () {
      CatalogPackFiltersRegistry.seedFromJson('test-hub-pack', {
        'play': [
          {
            'id': 'audio',
            'field': 'category',
            'style': 'grouped',
            'default': 'sub',
            'options': [
              {'id': 'sub', 'label': 'SUB', 'value': 'sub'},
              {'id': 'dub', 'label': 'DUB', 'value': 'dub'},
            ],
          },
        ],
      });

      final specs = CatalogPackFiltersRegistry.playFiltersFor('test-hub-pack');
      expect(specs, hasLength(1));
      expect(specs.first.field, 'category');
      expect(specs.first.initialValue(null), 'sub');
      expect(
        specs.first.initialValue({'category': 'dub'}),
        'dub',
      );
      expect(
        catalogPlayAudioCategory({'category': 'dub'}),
        'dub',
      );
    });
  });
}
