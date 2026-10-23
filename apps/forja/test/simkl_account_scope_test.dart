import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';
import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LocalDataScope.resetForTest();
    await ForjaPlatformSecureStore.ensureConsentLoaded();
    SimklService.clearWatchlistCache();
  });

  test('Simkl token is isolated per account and survives rebind', () async {
    await LocalDataScope.configure(accountId: 'acct-a', profileId: 'prof-1');
    final simkl = SimklService();
    await ForjaPlatformSecureStore.write(
      LocalDataScope.storageKey('simkl_access_token'),
      'token-a',
    );
    expect(await simkl.isLoggedIn(), isTrue);

    await LocalDataScope.configure(accountId: 'acct-b', profileId: 'prof-1');
    expect(await simkl.isLoggedIn(), isFalse);

    await LocalDataScope.configure(accountId: 'acct-a', profileId: 'prof-1');
    expect(await simkl.isLoggedIn(), isTrue);
    expect(
      await ForjaPlatformSecureStore.read(
        LocalDataScope.storageKey('simkl_access_token'),
      ),
      'token-a',
    );

    await LocalDataScope.configure(accountId: null, profileId: null);
    expect(await simkl.isLoggedIn(), isFalse);
    expect(
      await ForjaPlatformSecureStore.read('simkl_access_token@acct-a:prof-1'),
      'token-a',
    );
  });

  test('legacy bare Simkl token migrates into first non-guest scope', () async {
    await ForjaPlatformSecureStore.write('simkl_access_token', 'legacy-token');

    await LocalDataScope.configure(accountId: null, profileId: null);
    final simkl = SimklService();
    expect(await simkl.isLoggedIn(), isFalse);
    expect(
      await ForjaPlatformSecureStore.read('simkl_access_token'),
      'legacy-token',
    );

    await LocalDataScope.configure(accountId: 'acct-a', profileId: 'prof-1');
    expect(await simkl.isLoggedIn(), isTrue);
    expect(await ForjaPlatformSecureStore.read('simkl_access_token'), isNull);
    expect(
      await ForjaPlatformSecureStore.read('simkl_access_token@acct-a:prof-1'),
      'legacy-token',
    );
  });
}
