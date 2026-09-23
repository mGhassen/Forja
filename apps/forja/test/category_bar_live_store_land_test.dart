import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/portals/models.dart';
import 'package:forja/shared/engine/runtime/actions/category_bar/category_bar_action_host.dart';
import 'package:forja/shared/engine/runtime/kit/hosts/iptv_catalog_land.dart';

void main() {
  tearDown(IptvCatalogLand.clearLastCategoryMemForTest);

  const items = [
    PortalLiveCatalog.favoritesId,
    PortalLiveCatalog.watchedId,
    '10',
    '20',
    '30',
  ];

  test('store land prefers last category over painter first snap', () {
    expect(
      CategoryBarActionHost.resolveLiveStoreCategoryLand(
        // Painter already snapped to first portal group.
        selectedId: '10',
        preferCategoryId: '30',
        itemIds: items,
      ),
      '30',
    );
  });

  test('store land keeps Favorites when that is the current selection', () {
    expect(
      CategoryBarActionHost.resolveLiveStoreCategoryLand(
        selectedId: PortalLiveCatalog.favoritesId,
        preferCategoryId: '30',
        itemIds: items,
      ),
      isNull,
    );
  });

  test('store land falls back to first portal group without prefer', () {
    expect(
      CategoryBarActionHost.resolveLiveStoreCategoryLand(
        selectedId: '',
        preferCategoryId: null,
        itemIds: items,
      ),
      '10',
    );
  });

  test('store land ignores missing prefer and skips synthetics', () {
    expect(
      CategoryBarActionHost.resolveLiveStoreCategoryLand(
        selectedId: '',
        preferCategoryId: 'missing',
        itemIds: items,
      ),
      '10',
    );
  });

  test('peekLastCategory reads session mem', () {
    IptvCatalogLand.seedLastCategoryMemForTest('portal-a', '30');
    expect(IptvCatalogLand.peekLastCategory('portal-a'), '30');
    expect(IptvCatalogLand.peekLastCategory('other'), isNull);
  });

  test('patchCachedFavorites updates sync cache for Favorites paint', () {
    CategoryBarActionHost.cachedLiveListParams = {
      'portalStoreKey': 'https://x|u|p',
      'favorites': <String>['a'],
      'watched': <String>[],
    };
    CategoryBarActionHost.patchCachedFavorites({'a', 'b'});
    expect(
      CategoryBarActionHost.cachedFavoriteIds(
        portalKeyOrVaultKey: 'https://x|u',
      ),
      {'a', 'b'},
    );
    expect(
      CategoryBarActionHost.cachedFavoriteIds(
        portalKeyOrVaultKey: 'https://other|u',
      ),
      isNull,
    );
    CategoryBarActionHost.cachedLiveListParams = const {};
  });

  test('resolveLiveStoreKey prefers cached portalStoreKey', () async {
    CategoryBarActionHost.cachedLiveListParams = {
      'portalStoreKey': 'https://x|u|p',
      'favorites': <String>[],
    };
    expect(
      await CategoryBarActionHost.resolveLiveStoreKey('https://x|u'),
      'https://x|u|p',
    );
    expect(
      await CategoryBarActionHost.resolveLiveStoreKey('https://x|u|p'),
      'https://x|u|p',
    );
    CategoryBarActionHost.cachedLiveListParams = const {};
  });
}
