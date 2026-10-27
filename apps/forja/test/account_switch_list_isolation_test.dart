import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/cache/engine_cache.dart';
import 'package:forja/shared/engine/packs/registry/plugin_registry.dart';
import 'package:forja/shared/engine/store/list_providers.dart';
import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LocalDataScope.resetForTest();
    PluginRegistry.debugResetHubOpenReload();
    EngineCache.instance.wipeAll();
    listFeedEpochListenable.value = 0;
  });

  test(
    'identity rebind busts list feed epoch + flags hub clear-paint reload',
    () async {
      await LocalDataScope.configure(accountId: 'acct_a', profileId: 'p1');
      final feedKey = EngineCache.keyFor(
        pluginId: 'test-list-hub',
        action: 'feed',
        params: const {},
      );
      EngineCache.instance.putEntry(
        key: feedKey,
        pluginId: 'test-list-hub',
        data: {
          'rails': {
            'watching': [
              {'id': 'item_a', 'title': 'Account A title'},
            ],
          },
        },
      );
      expect(EngineCache.instance.getEntry(feedKey), isNotNull);

      final epochBefore = listFeedEpochListenable.value;
      await LocalDataScope.configure(accountId: 'acct_b', profileId: 'p1');
      bustIdentityBoundHubUiCaches();

      expect(listFeedEpochListenable.value, greaterThan(epochBefore));
      expect(PluginRegistry.hubNeedsReloadOnOpen('test-list-hub'), isTrue);
      expect(
        EngineCache.instance.getEntry(feedKey),
        isNull,
        reason: 'previous account feed must not survive identity rebind',
      );
    },
  );
}
