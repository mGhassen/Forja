import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/cache/engine_cache.dart';
import 'package:forja/shared/engine/portals/models.dart';
import 'package:forja/shared/engine/portals/portals_host.dart';
import 'package:forja/shared/engine/portals/store/storage.dart';

void main() {
  tearDown(() {
    EngineCache.instance.wipeCatalog();
  });

  test('soft select wipe drops empty cover cached under portalStoreKey', () {
    const pluginId = 'test-hub-portals';
    final first = const Portal(
      url: 'http://portal.example',
      username: 'user-a',
      password: 'x',
    );
    final poisonedKey = EngineCache.keyFor(
      pluginId: pluginId,
      action: 'feed',
      params: {
        'section': 'live',
        'portalStoreKey': PortalAliveStore.portalKey(first),
      },
    );
    EngineCache.instance.putEntry(
      key: poisonedKey,
      pluginId: pluginId,
      data: const {
        'emptyTitle': 'Choose a portal',
        'coverBody': true,
        'items': <dynamic>[],
      },
    );
    expect(EngineCache.instance.getEntry(poisonedKey), isNotNull);

    EngineCache.instance.wipePlugin(pluginId);
    expect(EngineCache.instance.getEntry(poisonedKey), isNull);
  });

  test('unmatched host key → empty (mirror must pass null, not clear)', () {
    final portals = <VerifiedPortal>[
      VerifiedPortal(
        portal: const Portal(
          url: 'http://other.example',
          username: 'u',
          password: 'p',
        ),
        name: 'other',
        expiry: '',
        maxConnections: '1',
        activeConnections: '0',
      ),
    ];
    // Legacy host key not in store — empty means leave vault active alone.
    expect(
      PortalsHost.packActiveKeyAmong(
        'xtream|http://portal.example|user-a|secret',
        portals,
      ),
      isEmpty,
    );
  });
}
