import 'package:flutter_test/flutter_test.dart';
import 'package:rust/src/secure_settings.dart';

void main() {
  test('forbiddenCanonicalKeys covers credentials that must not sit in JSON', () {
    expect(SecureSettings.forbiddenCanonicalKeys, contains('rd_access_token'));
    expect(SecureSettings.forbiddenCanonicalKeys, contains('torbox_api_key'));
    expect(SecureSettings.forbiddenCanonicalKeys, contains('jackett_api_key'));
    expect(SecureSettings.forbiddenCanonicalKeys, contains('prowlarr_api_key'));
    expect(
      SecureSettings.forbiddenCanonicalKeys,
      containsAll(SecureSettings.retiredSecureKeys),
    );
    expect(
      SecureSettings.forbiddenCanonicalKeys,
      contains('iptv_portal_passwords_v1'),
    );
    // Non-secret configuration must remain allowed in the canonical file.
    expect(
      SecureSettings.forbiddenCanonicalKeys.contains('stream_provider_order'),
      isFalse,
    );
    expect(
      SecureSettings.forbiddenCanonicalKeys.contains('nuvio_addons_v1'),
      isFalse,
    );
  });
}
