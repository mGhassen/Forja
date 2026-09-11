import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/foundation/components/layout/kit_types.dart';

/// RFC-106 G14-C — pack layout wire freeze (aliases + opaque slot types).
///
/// Synthetic type strings only. No shipped pack ids.
void main() {
  group('KitTypes.normalize — composition aliases', () {
    test('stack', () {
      expect(KitTypes.normalize('kit.stack'), KitTypes.stack);
      expect(KitTypes.normalize('stack'), KitTypes.stack);
    });

    test('menu', () {
      expect(KitTypes.normalize('kit.menu'), KitTypes.menu);
      expect(KitTypes.normalize('menu'), KitTypes.menu);
    });

    test('tabs', () {
      expect(KitTypes.normalize('tabs'), KitTypes.tabs);
      expect(KitTypes.normalize('kit.tabs'), KitTypes.tabs);
      expect(
        KitTypes.normalize('tabs', {'style': 'kind'}),
        KitTypes.menu,
      );
    });

    test('list', () {
      expect(KitTypes.normalize('kit.list'), KitTypes.list);
      expect(KitTypes.normalize('my_list'), KitTypes.list);
      expect(KitTypes.normalize('host.my_list'), KitTypes.list);
    });

    test('row / rail / ranked', () {
      expect(KitTypes.normalize('kit.row'), KitTypes.row);
      expect(KitTypes.normalize('rail'), KitTypes.row);
      expect(KitTypes.normalize('ranked'), KitTypes.row);
    });

    test('topBar', () {
      expect(KitTypes.normalize('kit.topBar'), KitTypes.topBar);
      expect(KitTypes.normalize('topBar'), KitTypes.topBar);
      expect(KitTypes.normalize('kit.top_bar'), KitTypes.topBar);
    });

    test('categoryBar', () {
      expect(KitTypes.normalize('kit.categoryBar'), KitTypes.categoryBar);
      expect(KitTypes.normalize('categoryBar'), KitTypes.categoryBar);
      expect(KitTypes.normalize('kit.category_bar'), KitTypes.categoryBar);
      expect(KitTypes.normalize('kinds'), KitTypes.categoryBar);
    });
  });

  group('KitTypes.normalize — section slot aliases', () {
    test('hero', () {
      expect(KitTypes.normalize('hero'), KitTypes.hero);
      expect(KitTypes.normalize('cinematic_hero'), KitTypes.hero);
    });

    test('mood', () {
      expect(KitTypes.normalize('mood'), KitTypes.mood);
    });

    test('continue', () {
      expect(KitTypes.normalize('continue'), KitTypes.continueWatching);
      expect(KitTypes.normalize('host.continue'), KitTypes.continueWatching);
    });

    test('because', () {
      expect(KitTypes.normalize('because'), KitTypes.because);
      expect(KitTypes.normalize('host.because'), KitTypes.because);
    });

    test('vertical_filters / host.vertical_filters / watch_providers', () {
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
        walkKitWidgets(roots, (spec) {
          final raw = (spec['type'] ?? '').toString();
          final n = KitTypes.normalize(raw, spec);
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
