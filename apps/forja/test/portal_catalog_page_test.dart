import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/portals/store/portal_catalog_page.dart';

void main() {
  Map<String, dynamic> row(String id, String name, String cat) => {
        'id': id,
        'stream_id': id,
        'name': name,
        'category_id': cat,
      };

  final streams = [
    row('1', 'Alpha', 'a'),
    row('2', 'Beta', 'a'),
    row('3', 'Gamma', 'b'),
    row('4', 'Alpine', 'b'),
  ];

  test('filterSort by category', () {
    final out = PortalCatalogPage.filterSort(
      streams: streams,
      categoryId: 'a',
    );
    expect(out.map((e) => e['id']), ['1', '2']);
  });

  test('filterSort by q across shelf', () {
    final out = PortalCatalogPage.filterSort(
      streams: streams,
      q: 'alp',
    );
    expect(out.map((e) => e['id']), ['1', '4']);
  });

  test('filterSort nameAsc', () {
    final out = PortalCatalogPage.filterSort(
      streams: streams,
      categoryId: 'a',
      sort: 'nameAsc',
    );
    expect(out.map((e) => e['name']), ['Alpha', 'Beta']);
  });

  test('filterSort stream_ids preserves order', () {
    final out = PortalCatalogPage.filterSort(
      streams: streams,
      streamIds: ['3', '1', 'missing'],
    );
    expect(out.map((e) => e['id']), ['3', '1']);
  });
}
