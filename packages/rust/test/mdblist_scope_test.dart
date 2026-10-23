import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LocalDataScope.resetForTest();
    await ForjaPlatformSecureStore.ensureConsentLoaded();
  });

  test('MDBList API key is isolated per account', () async {
    await LocalDataScope.configure(accountId: 'acct-a', profileId: 'p1');
    final mdblist = MdblistService();
    await mdblist.setApiKey('key-a');
    expect(await mdblist.isConfigured(), isTrue);

    await LocalDataScope.configure(accountId: 'acct-b', profileId: 'p1');
    expect(await mdblist.isConfigured(), isFalse);

    await LocalDataScope.configure(accountId: 'acct-a', profileId: 'p1');
    expect(await mdblist.getApiKey(), 'key-a');

    await LocalDataScope.configure(accountId: null, profileId: null);
    expect(await mdblist.isConfigured(), isFalse);
    expect(
      await ForjaPlatformSecureStore.read('mdblist_api_key@acct-a:p1'),
      'key-a',
    );
  });
}
