import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/iptv/data/models.dart';
import 'package:forja/features/iptv/data/storage.dart';
import 'package:forja/shared/sync/src/sync_domain_bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('wipeLocalIptvInventoryForProfileBoundary clears portals + passwords',
      () async {
    const portal = IptvPortal(
      url: 'http://example.com',
      username: 'u',
      password: 'secret',
      source: 'Manual',
    );
    await IptvStore.save(const [
      VerifiedPortal(
        portal: portal,
        label: 'Other profile portal',
        name: 'Example',
        expiry: '',
        maxConnections: '1',
        activeConnections: '0',
      ),
    ]);
    await IptvStore.saveFavorites({portal.key});
    await IptvStore.saveLastPortalKey(portal.key);

    expect(await IptvStore.load(), isNotEmpty);
    expect(await IptvStore.loadFavorites(), isNotEmpty);
    expect(await IptvStore.loadLastPortalKey(), portal.key);

    await SyncDomainBridge.instance.wipeLocalIptvInventoryForProfileBoundary();

    expect(await IptvStore.load(), isEmpty);
    expect(await IptvStore.loadFavorites(), isEmpty);
    expect(await IptvStore.loadLastPortalKey(), isNull);
  });
}
