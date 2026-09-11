import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/protocol/layout_types.dart';

/// RFC-106 G14-C — pack layout wire freeze (aliases + opaque slot types).
///
/// Synthetic type strings only. No shipped pack ids.
void main() {
  group('LayoutTypes.normalize — composition aliases', () {
    test('stack', () {
      expect(LayoutTypes.normalize('kit.stack'), LayoutTypes.stack);
      expect(LayoutTypes.normalize('stack'), LayoutTypes.stack);
    });

    test('menu', () {
      expect(LayoutTypes.normalize('kit.menu'), LayoutTypes.menu);
      expect(LayoutTypes.normalize('menu'), LayoutTypes.menu);
    });

    test('tabs', () {
      expect(LayoutTypes.normalize('tabs'), LayoutTypes.tabs);
      expect(LayoutTypes.normalize('kit.tabs'), LayoutTypes.tabs);
      expect(
        LayoutTypes.normalize('tabs', {'style': 'kind'}),
        LayoutTypes.menu,
      );
    });

    test('list', () {
      expect(LayoutTypes.normalize('kit.list'), LayoutTypes.list);
      expect(LayoutTypes.normalize('my_list'), LayoutTypes.list);
      expect(LayoutTypes.normalize('host.my_list'), LayoutTypes.list);
    });

    test('row / rail / ranked', () {
      expect(LayoutTypes.normalize('kit.row'), LayoutTypes.row);
      expect(LayoutTypes.normalize('rail'), LayoutTypes.row);
      expect(LayoutTypes.normalize('ranked'), LayoutTypes.row);
    });

    test('topBar', () {
      expect(LayoutTypes.normalize('kit.topBar'), LayoutTypes.topBar);
      expect(LayoutTypes.normalize('topBar'), LayoutTypes.topBar);
      expect(LayoutTypes.normalize('kit.top_bar'), LayoutTypes.topBar);
    });

    test('categoryBar', () {
      expect(LayoutTypes.normalize('kit.categoryBar'), LayoutTypes.categoryBar);
      expect(LayoutTypes.normalize('categoryBar'), LayoutTypes.categoryBar);
      expect(LayoutTypes.normalize('kit.category_bar'), LayoutTypes.categoryBar);
      expect(LayoutTypes.normalize('kinds'), LayoutTypes.categoryBar);
    });
  });

  group('LayoutTypes.normalize — section slot aliases', () {
    test('hero', () {
      expect(LayoutTypes.normalize('hero'), LayoutTypes.hero);
      expect(LayoutTypes.normalize('cinematic_hero'), LayoutTypes.hero);
    });

    test('mood', () {
      expect(LayoutTypes.normalize('mood'), LayoutTypes.mood);
    });

    test('continue', () {
      expect(LayoutTypes.normalize('continue'), LayoutTypes.continueWatching);
      expect(LayoutTypes.normalize('host.continue'), LayoutTypes.continueWatching);
    });

    test('because', () {
      expect(LayoutTypes.normalize('because'), LayoutTypes.because);
      expect(LayoutTypes.normalize('host.because'), LayoutTypes.because);
    });

    test('vertical_filters / host.vertical_filters / watch_providers', () {
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
  });

  group('synthetic hub layout fixtures', () {
    final dir = Directory('test/fixtures/kit_layouts');

    test('fixtures dir exists', () {
      expect(dir.existsSync(), isTrue);
    });

    for (final name in const [
      'hub_home_layout.json',
      'hub_catalog_layout.json',
      'hub_list_layout.json',
      'hub_live_layout.json',
    ]) {
      test('$name walks without unknown fallthrough', () {
        final file = File('${dir.path}/$name');
        expect(file.existsSync(), isTrue, reason: name);
        final root = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        final layout = root['layout'];
        expect(layout, isA<List>(), reason: '$name layout');
        final roots = [
          for (final e in layout as List)
            if (e is Map) Map<String, dynamic>.from(e),
        ];
        expect(roots, isNotEmpty);

        final seen = <String>{};
        walkLayoutWidgets(roots, (spec) {
          final raw = (spec['type'] ?? '').toString();
          final n = LayoutTypes.normalize(raw, spec);
          seen.add(n);
          expect(n, isNotEmpty);
          // Opaque plugin id must stay test data.
          final pluginId = (spec['pluginId'] ?? root['pluginId'] ?? '').toString();
          if (pluginId.isNotEmpty) {
            expect(pluginId.startsWith('test-'), isTrue, reason: pluginId);
          }
        });
        expect(seen, isNotEmpty);
      });
    }
  });
}
