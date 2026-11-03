import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ForjaPlatformSecureStore.ensureConsentLoaded();
  });

  test('prefs vault round-trip survives write/read', () async {
    const key = 'sb-test.supabase.co-auth-token';
    const value = '{"access_token":"x","refresh_token":"y"}';

    await ForjaPlatformSecureStore.write(key, value);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ForjaPlatformSecureStore.prefsKey(key)), value);

    final read = await ForjaPlatformSecureStore.read(key);
    expect(read, value);
  });

  test('delete clears prefs vault copy', () async {
    const key = 'sb-test.supabase.co-auth-token';
    await ForjaPlatformSecureStore.write(key, 'session-blob');
    await ForjaPlatformSecureStore.delete(key);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ForjaPlatformSecureStore.prefsKey(key)), isNull);
    expect(await ForjaPlatformSecureStore.read(key), isNull);
  });
}
