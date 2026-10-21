import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/packs/settings/pack_connected_auth_service.dart';
import 'package:forja/shared/engine/packs/settings/pack_settings_store.dart';
import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every green Play racer asks for its own Connected Services overlay. A
/// plugin that never logged in must not touch the secret store at all — on a
/// device that is one Keystore round trip per default secret id per racer.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pluginId = 'test-provider-a';
  // On the test host the secure store is the prefs vault, so a value seeded
  // there is exactly what an unguarded read would surface.
  final vaultKey = ForjaPlatformSecureStore.prefsKey(
    PackSettingsStore.secretKey(pluginId, 'jwt'),
  );

  test('no session → empty overlay without reading secrets', () async {
    SharedPreferences.setMockInitialValues({vaultKey: 'leftover-token'});
    expect(await PackConnectedAuthStore.hasSession(pluginId), isFalse);
    expect(await PackConnectedAuthStore.configOverlay(pluginId), isEmpty);
  });

  test('tracked session → secrets are read', () async {
    SharedPreferences.setMockInitialValues({
      vaultKey: 'tok',
      'pack_auth_secret_ids_v1_$pluginId': <String>['jwt'],
    });
    expect(await PackConnectedAuthStore.hasSession(pluginId), isTrue);
    final overlay = await PackConnectedAuthStore.configOverlay(pluginId);
    expect(overlay['jwt'], 'tok');
  });

  test('clearSession removes the marker so later reads stay cheap', () async {
    SharedPreferences.setMockInitialValues({
      vaultKey: 'tok',
      'pack_auth_secret_ids_v1_$pluginId': <String>['jwt'],
    });
    await PackConnectedAuthStore.clearSession(pluginId);
    expect(await PackConnectedAuthStore.hasSession(pluginId), isFalse);
    expect(await PackConnectedAuthStore.configOverlay(pluginId), isEmpty);
  });

  test('default secret ids are still tracked for an active session', () async {
    SharedPreferences.setMockInitialValues({
      'pack_auth_secret_ids_v1_$pluginId': <String>['custom'],
    });
    final ids = await PackConnectedAuthStore.trackedSecretIds(pluginId);
    expect(ids, containsAll(PackConnectedAuthStore.defaultSecretIds));
    expect(ids, contains('custom'));
  });
}
