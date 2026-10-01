import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/runtime/kit/hosts/iptv_catalog_land.dart';

void main() {
  tearDown(() {
    IptvCatalogLand.clearVisibleStreamIds();
    IptvCatalogLand.cancelSyntheticFocusSchedule();
  });

  test('clearVisibleStreamIds drops painted channel ids', () {
    IptvCatalogLand.setVisibleStreamIds(['a', 'b', 'c']);
    expect(IptvCatalogLand.streamVisibleInFilter('b'), isTrue);
    expect(IptvCatalogLand.indexOfVisibleStream('c'), 2);

    IptvCatalogLand.clearVisibleStreamIds();

    expect(IptvCatalogLand.streamVisibleInFilter('b'), isFalse);
    expect(IptvCatalogLand.indexOfVisibleStream('a'), isNull);
  });

  test('focusItemsFromCategory returns false when the grid is empty', () {
    IptvCatalogLand.clearVisibleStreamIds();
    expect(
      IptvCatalogLand.focusItemsFromCategory(tabId: 'iptv', preferFirst: true),
      isFalse,
    );
  });
}
