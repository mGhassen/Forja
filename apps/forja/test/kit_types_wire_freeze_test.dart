import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/protocol/layout_types.dart';

/// RFC-106 G14-C — pack layout wire freeze.
///
/// Hub packs emit these type strings. Normalize must stay stable across the
/// foundation package cutover (aliases + `tabs` style kind→menu).
void main() {
  group('LayoutTypes.normalize pack wire freeze', () {
    test('stack aliases', () {
      expect(LayoutTypes.normalize('kit.stack'), LayoutTypes.stack);
      expect(LayoutTypes.normalize('stack'), LayoutTypes.stack);
    });

    test('menu aliases', () {
      expect(LayoutTypes.normalize('kit.menu'), LayoutTypes.menu);
      expect(LayoutTypes.normalize('menu'), LayoutTypes.menu);
    });

    test('list aliases', () {
      expect(LayoutTypes.normalize('kit.list'), LayoutTypes.list);
      expect(LayoutTypes.normalize('kit.list'), LayoutTypes.list);
    });

    test('row aliases', () {
      expect(LayoutTypes.normalize('kit.row'), LayoutTypes.row);
      expect(LayoutTypes.normalize('rail'), LayoutTypes.row);
      expect(LayoutTypes.normalize('ranked'), LayoutTypes.row);
    });

    test('topBar aliases', () {
      expect(LayoutTypes.normalize('kit.topBar'), LayoutTypes.topBar);
      expect(LayoutTypes.normalize('topBar'), LayoutTypes.topBar);
    });

    test('categoryBar aliases', () {
      expect(LayoutTypes.normalize('kit.categoryBar'), LayoutTypes.categoryBar);
      expect(LayoutTypes.normalize('kinds'), LayoutTypes.categoryBar);
    });

    test('tabs — default stays tabs; style kind → menu', () {
      expect(LayoutTypes.normalize('tabs'), LayoutTypes.tabs);
      expect(LayoutTypes.normalize('kit.tabs'), LayoutTypes.tabs);
      expect(
        LayoutTypes.normalize('tabs', {'style': 'kind'}),
        LayoutTypes.menu,
      );
    });

    test('vertical_filters aliases → VerticalMenu path', () {
      expect(
        LayoutTypes.normalize('vertical_filters'),
        LayoutTypes.verticalFilters,
      );
      expect(
        LayoutTypes.normalize('host.vertical_filters'),
        LayoutTypes.verticalFilters,
      );
      expect(
        LayoutTypes.normalize('watch_providers'),
        LayoutTypes.verticalFilters,
      );
    });

    test('hero / mood / continue / because', () {
      expect(LayoutTypes.normalize('hero'), LayoutTypes.hero);
      expect(LayoutTypes.normalize('cinematic_hero'), LayoutTypes.hero);
      expect(LayoutTypes.normalize('mood'), LayoutTypes.mood);
      expect(LayoutTypes.normalize('continue'), LayoutTypes.continueWatching);
      expect(LayoutTypes.normalize('host.continue'), LayoutTypes.continueWatching);
      expect(LayoutTypes.normalize('because'), LayoutTypes.because);
      expect(LayoutTypes.normalize('host.because'), LayoutTypes.because);
    });
  });
}
