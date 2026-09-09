import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/models/models.dart';
import 'package:forja/shared/foundation/services/pack/pack_addon_settings_spec.dart';
import 'package:forja/shared/foundation/services/pack/pack_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('pack password settings', () {
    test('parses password field type', () {
      final plugin = EnginePlugin.fromJson({
        'id': 'test-provider-secret',
        'name': 'Secret Provider',
        'entry': 'a.js',
        'kind': 'http',
        'settings': {
          'group': 'Account',
          'fields': [
            {'id': 'email', 'type': 'text', 'label': 'Email'},
            {'id': 'password', 'type': 'password', 'label': 'Password'},
          ],
        },
      });
      final spec = PackAddonSettingsSpec.fromPlugin(plugin);
      expect(spec, isNotNull);
      expect(spec!.fields.length, 2);
      expect(spec.fields[1].type, PackAddonSettingsFieldType.password);
    });

    test('loadConfigOverlay merges text + secret', () async {
      final plugin = EnginePlugin.fromJson({
        'id': 'test-provider-secret',
        'name': 'Secret Provider',
        'entry': 'a.js',
        'kind': 'http',
        'settings': {
          'group': 'Account',
          'fields': [
            {
              'id': 'email',
              'type': 'text',
              'label': 'Email',
              'default': '',
            },
            {'id': 'password', 'type': 'secret', 'label': 'Password'},
          ],
        },
      });
      await PackSettingsStore.setString(
        'test-provider-secret',
        'email',
        'user@example.com',
      );
      await PackSettingsStore.setSecret(
        'test-provider-secret',
        'password',
        's3cret',
      );
      final spec = PackAddonSettingsSpec.fromPlugin(plugin)!;
      final overlay = await spec.loadConfigOverlay();
      expect(overlay['email'], 'user@example.com');
      expect(overlay['password'], 's3cret');
    });
  });
}
