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

  test('Movies/Series paint ids are tracked like Live stream ids', () {
    IptvCatalogLand.setVisibleStreamIds([
      'iptv:vod:portal:1',
      'iptv:series:portal:2',
    ]);
    expect(IptvCatalogLand.indexOfVisibleStream('iptv:vod:portal:1'), 0);
    expect(IptvCatalogLand.indexOfVisibleStream('iptv:series:portal:2'), 1);
    expect(
      IptvCatalogLand.streamVisibleInFilter('iptv:series:portal:2'),
      isTrue,
    );
  });
}
