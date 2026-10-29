import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory vaultDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ForjaPlatformSecureStore.resetForTest();
    vaultDir = await Directory.systemTemp.createTemp(
      'forja_secure_vault_test_',
    );
    ForjaPlatformSecureStore.debugFileVaultRoot = vaultDir;
  });

  tearDown(() async {
    ForjaPlatformSecureStore.resetForTest();
    if (await vaultDir.exists()) {
      await vaultDir.delete(recursive: true);
    }
  });

  test('file vault recovers session after prefs vault cleared', () async {
    const key = 'sb-emulator.example.com-auth-token';
    const value = '{"access_token":"a","refresh_token":"r"}';

    await ForjaPlatformSecureStore.write(key, value);

    final files = vaultDir.listSync().whereType<File>().toList();
    expect(files, isNotEmpty);
    expect(files.single.path.endsWith('.secret'), isTrue);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ForjaPlatformSecureStore.prefsKey(key));
    await prefs.remove(key);

    expect(await ForjaPlatformSecureStore.read(key), value);

    await ForjaPlatformSecureStore.delete(key);
    expect(await ForjaPlatformSecureStore.read(key), isNull);
    expect(vaultDir.listSync().whereType<File>(), isEmpty);
  });
}
