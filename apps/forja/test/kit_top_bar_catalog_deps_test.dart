import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/shell/kit_top_bar_actions.dart';

void main() {
  test('kitTopBarCatalogDeps reads opaque deps from catalog actions', () {
    expect(
      kitTopBarCatalogDeps([
        {
          'id': 'catalog',
          'dynamicCatalogs': true,
          'deps': ['stremio', 'Stremio'],
        },
        {'id': 'horizon'},
      ]),
      ['stremio'],
    );
  });

  test('kitTopBarCatalogDeps ignores non-catalog actions', () {
    expect(
      kitTopBarCatalogDeps([
        {
          'id': 'refresh',
          'deps': ['stremio'],
        },
      ]),
      isEmpty,
    );
  });

  test('kitTopBarCatalogDepsKey joins sorted tokens', () {
    expect(kitTopBarCatalogDepsKey(const ['stremio']), 'stremio');
    expect(kitTopBarCatalogDepsKey(const []), '');
  });
}
