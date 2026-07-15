import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/iptv/iptv/data/models.dart';
import 'package:forja/features/iptv/iptv/data/storage.dart';
import 'package:forja/shared/playback/settings_data_cleaner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('clearIptvPortalCaches removes alive + channel hits, keeps portals',
      () async {
    const portal = IptvPortal(
      url: 'http://example.com',
      username: 'u',
      password: 'p',
      source: 'Manual',
    );
    final key = IptvAliveStore.portalKey(portal);
    await IptvAliveStore.save(
      key,
      const AliveSnapshot(checkedAt: 1, aliveIds: {'1', '2'}),
    );
    await IptvAliveStore.saveLiveOnly(key, true);
    await IptvChannelResultsStore.save('bbc', const [
      StoredHit(
        portalUrl: 'http://example.com',
        portalUser: 'u',
        portalPass: 'p',
        portalName: 'Ex',
        streamId: '1',
        streamName: 'BBC',
        streamIcon: '',
        streamCategoryId: '',
        streamContainerExt: 'ts',
        streamKind: 'live',
        streamUrl: 'http://example.com/1',
      ),
    ]);
    await IptvChannelFavoritesStore.save('bbc', {'http://example.com/1'});
    await IptvStore.save(const [
      VerifiedPortal(
        portal: portal,
        name: 'Example',
        expiry: '',
        maxConnections: '1',
        activeConnections: '0',
      ),
    ]);
    await IptvStore.saveFavorites({portal.key});

    await SettingsDataCleaner.clearIptvPortalCaches();

    expect(await IptvAliveStore.load(key), isNull);
    expect(await IptvAliveStore.loadLiveOnly(key), isFalse);
    expect(await IptvChannelResultsStore.load('bbc'), isEmpty);
    expect(await IptvChannelFavoritesStore.load('bbc'),
        {'http://example.com/1'});
    expect((await IptvStore.load()).single.name, 'Example');
    expect(await IptvStore.loadFavorites(), {portal.key});
  });
}
