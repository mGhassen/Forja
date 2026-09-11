import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/kit/kit_sources_live_tv_browse.dart';
import 'package:forja/shared/kit/kit_sources_panel.dart';

void main() {
  KitSourcesRow row({
    required String id,
    required String title,
    String? subtitle,
    String? footer,
    List<String> badges = const [],
  }) {
    return KitSourcesRow(
      id: id,
      title: title,
      subtitle: subtitle,
      footer: footer,
      badges: badges,
    );
  }

  group('kitSourcesCategoriesFromRows', () {
    test('buckets by subtitle in first-appearance order', () {
      final rows = [
        row(id: '1', title: 'Sky F1', subtitle: 'Sports'),
        row(id: '2', title: 'ESPN', subtitle: 'Sports'),
        row(id: '3', title: 'CNN', subtitle: 'News'),
        row(id: '4', title: 'Mystery'),
      ];
      final cats = kitSourcesCategoriesFromRows(rows);
      expect(cats.map((c) => c.key).toList(), ['Sports', 'News', 'Other']);
      expect(cats.map((c) => c.count).toList(), [2, 1, 1]);
    });
  });

  group('kitSourcesFilterByCategory', () {
    test('All returns every row', () {
      final rows = [
        row(id: '1', title: 'A', subtitle: 'Sports'),
        row(id: '2', title: 'B', subtitle: 'News'),
      ];
      expect(
        kitSourcesFilterByCategory(rows, kKitSourcesCategoryAll),
        rows,
      );
    });

    test('filters to selected category', () {
      final rows = [
        row(id: '1', title: 'A', subtitle: 'Sports'),
        row(id: '2', title: 'B', subtitle: 'News'),
        row(id: '3', title: 'C', subtitle: 'Sports'),
      ];
      final filtered = kitSourcesFilterByCategory(rows, 'Sports');
      expect(filtered.map((r) => r.id).toList(), ['1', '3']);
    });
  });

  group('kitSourcesFilterByQuery', () {
    test('matches title, subtitle, footer, badges', () {
      final rows = [
        row(id: '1', title: 'Sky Sports F1', subtitle: 'Racing'),
        row(id: '2', title: 'ESPN', subtitle: 'Sports', footer: 'line.mag.eu'),
        row(id: '3', title: 'CNN', badges: const ['HD']),
      ];
      expect(
        kitSourcesFilterByQuery(rows, 'f1').map((r) => r.id).toList(),
        ['1'],
      );
      expect(
        kitSourcesFilterByQuery(rows, 'mag').map((r) => r.id).toList(),
        ['2'],
      );
      expect(
        kitSourcesFilterByQuery(rows, 'hd').map((r) => r.id).toList(),
        ['3'],
      );
      expect(
        kitSourcesFilterByQuery(rows, 'racing').map((r) => r.id).toList(),
        ['1'],
      );
    });

    test('empty query returns all', () {
      final rows = [row(id: '1', title: 'A')];
      expect(kitSourcesFilterByQuery(rows, '  '), rows);
    });
  });
}
