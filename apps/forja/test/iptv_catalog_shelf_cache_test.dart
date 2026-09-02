import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/iptv/data/iptv_catalog_shelf_cache.dart';
import 'package:forja/features/iptv/data/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('parseShelfKey handles portal keys with pipe segments', () {
    const portalKey = 'xtream|https://host.tv|user|pass';
    const shelfKey = '$portalKey|live';
    final parsed = IptvCatalogShelfCache.parseShelfKey(shelfKey);
    expect(parsed, isNotNull);
    expect(parsed!.portalKey, portalKey);
    expect(parsed.section, IptvSection.live);
  });

  test('touch evicts oldest shelf after maxShelves', () async {
    final keys = <String>[];
    for (var i = 0; i < IptvCatalogShelfCache.maxShelves + 2; i++) {
      keys.add(
        IptvCatalogShelfCache.shelfKey(
          'xtream|https://p$i.tv|u|p',
          i.isEven ? IptvSection.live : IptvSection.vod,
        ),
      );
    }

    for (final key in keys.take(IptvCatalogShelfCache.maxShelves)) {
      final evicted = await IptvCatalogShelfCache.touch(key);
      expect(evicted, isEmpty);
    }

    final evicted = await IptvCatalogShelfCache.touch(
      keys[IptvCatalogShelfCache.maxShelves],
    );
    expect(evicted, [keys.first]);

    final evictedAgain = await IptvCatalogShelfCache.touch(
      keys[IptvCatalogShelfCache.maxShelves + 1],
    );
    expect(evictedAgain, [keys[1]]);
  });

  test('removePortal drops all shelves for one portal', () async {
    const portalKey = 'xtream|https://host.tv|user|pass';
    final live = IptvCatalogShelfCache.shelfKey(portalKey, IptvSection.live);
    final vod = IptvCatalogShelfCache.shelfKey(portalKey, IptvSection.vod);
    final other = IptvCatalogShelfCache.shelfKey(
      'xtream|https://other.tv|u|p',
      IptvSection.series,
    );

    await IptvCatalogShelfCache.touch(live);
    await IptvCatalogShelfCache.touch(vod);
    await IptvCatalogShelfCache.touch(other);

    await IptvCatalogShelfCache.removePortal(portalKey);

    final evicted = await IptvCatalogShelfCache.touch(
      IptvCatalogShelfCache.shelfKey(
        'xtream|https://fresh.tv|u|p',
        IptvSection.live,
      ),
    );
    expect(evicted, isEmpty);
    expect(
      await IptvCatalogShelfCache.touch(other),
      isEmpty,
    );
  });
}
