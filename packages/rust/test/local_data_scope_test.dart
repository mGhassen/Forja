import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LocalDataScope.resetForTest();
  });

  test('storageKey uses guest local:default by default', () {
    expect(LocalDataScope.id, 'local:default');
    expect(
      LocalDataScope.storageKey('watch_history'),
      'watch_history@local:default',
    );
  });

  test('configure switches identity and notifies listeners', () async {
    var hits = 0;
    Future<void> listener() async {
      hits++;
    }

    LocalDataScope.addListener(listener);
    await LocalDataScope.configure(accountId: 'user-a', profileId: 'prof-1');
    expect(LocalDataScope.id, 'user-a:prof-1');
    expect(LocalDataScope.storageKey('episodes_watched'),
        'episodes_watched@user-a:prof-1');
    expect(hits, 1);

    await LocalDataScope.configure(accountId: 'user-a', profileId: 'prof-1');
    expect(hits, 1); // unchanged scope — no notify

    await LocalDataScope.configure(accountId: null, profileId: null);
    expect(LocalDataScope.isGuest, isTrue);
    expect(hits, 2);
    LocalDataScope.removeListener(listener);
  });

  test('ownsKey matches active suffix', () async {
    await LocalDataScope.configure(accountId: 'u1', profileId: 'p1');
    expect(LocalDataScope.ownsKey('catalog_cw_x@u1:p1'), isTrue);
    expect(LocalDataScope.ownsKey('catalog_cw_x@u1:p2'), isFalse);
  });

  test('migrate copies string and stringList legacy keys without crashing',
      () async {
    SharedPreferences.setMockInitialValues({
      'episodes_watched': '{"a":true}',
      'pt_iptv_catalog_lru_v1': <String>['portal-1', 'portal-2'],
      'forja_player_stream_extract_cache_v1': <String>['{"k":1}'],
      'catalog_cw_hubx': <String>['cw1'],
    });
    await LocalDataScope.configure(accountId: null, profileId: null);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('episodes_watched@local:default'), '{"a":true}');
    expect(
      prefs.getStringList('pt_iptv_catalog_lru_v1@local:default'),
      ['portal-1', 'portal-2'],
    );
    expect(
      prefs.getStringList('forja_player_stream_extract_cache_v1@local:default'),
      ['{"k":1}'],
    );
    expect(prefs.getStringList('catalog_cw_hubx@local:default'), ['cw1']);
    expect(prefs.containsKey('episodes_watched'), isFalse);
    expect(prefs.containsKey('pt_iptv_catalog_lru_v1'), isFalse);
    expect(prefs.getBool('local_data_scope_v1_migrated'), isTrue);
  });
}
