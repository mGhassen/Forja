import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/kit/kit_types.dart';

/// RFC-106 G14-C — pack layout wire freeze.
///
/// Hub packs emit these type strings. Normalize must stay stable across the
/// foundation package cutover (aliases + `tabs` style kind→menu).
void main() {
  group('KitTypes.normalize pack wire freeze', () {
    test('stack aliases', () {
      expect(KitTypes.normalize('kit.stack'), KitTypes.stack);
      expect(KitTypes.normalize('stack'), KitTypes.stack);
    });

    test('menu aliases', () {
      expect(KitTypes.normalize('kit.menu'), KitTypes.menu);
      expect(KitTypes.normalize('menu'), KitTypes.menu);
    });

    test('list aliases', () {
      expect(KitTypes.normalize('kit.list'), KitTypes.list);
      expect(KitTypes.normalize('my_list'), KitTypes.list);
      expect(KitTypes.normalize('host.my_list'), KitTypes.list);
    });

    test('row aliases', () {
      expect(KitTypes.normalize('kit.row'), KitTypes.row);
      expect(KitTypes.normalize('rail'), KitTypes.row);
      expect(KitTypes.normalize('ranked'), KitTypes.row);
    });

    test('topBar aliases', () {
      expect(KitTypes.normalize('kit.topBar'), KitTypes.topBar);
      expect(KitTypes.normalize('topBar'), KitTypes.topBar);
    });

    test('categoryBar aliases', () {
      expect(KitTypes.normalize('kit.categoryBar'), KitTypes.categoryBar);
      expect(KitTypes.normalize('kinds'), KitTypes.categoryBar);
    });

    test('tabs — default stays tabs; style kind → menu', () {
      expect(KitTypes.normalize('tabs'), KitTypes.tabs);
      expect(KitTypes.normalize('kit.tabs'), KitTypes.tabs);
      expect(
        KitTypes.normalize('tabs', {'style': 'kind'}),
        KitTypes.menu,
      );
    });

    test('vertical_filters aliases → VerticalMenu path', () {
      expect(
        KitTypes.normalize('vertical_filters'),
        KitTypes.verticalFilters,
      );
      expect(
        KitTypes.normalize('host.vertical_filters'),
        KitTypes.verticalFilters,
      );
      expect(
        KitTypes.normalize('watch_providers'),
        KitTypes.verticalFilters,
      );
    });

    test('hero / mood / continue / because', () {
      expect(KitTypes.normalize('hero'), KitTypes.hero);
      expect(KitTypes.normalize('cinematic_hero'), KitTypes.hero);
      expect(KitTypes.normalize('mood'), KitTypes.mood);
      expect(KitTypes.normalize('continue'), KitTypes.continueWatching);
      expect(KitTypes.normalize('host.continue'), KitTypes.continueWatching);
      expect(KitTypes.normalize('because'), KitTypes.because);
      expect(KitTypes.normalize('host.because'), KitTypes.because);
    });
  });
}
