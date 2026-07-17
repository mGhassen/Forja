import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/sync/sync.dart';

void main() {
  test('ForjaCaptcha local always-pass key is the Cloudflare dummy', () {
    expect(
      ForjaCaptcha.localAlwaysPassSiteKey,
      '1x00000000000000000000AA',
    );
  });

  test('ForjaCaptcha.isConfigured follows TURNSTILE_SITE_KEY dart-define', () {
    // Default test binary has no TURNSTILE_SITE_KEY unless passed via
    // --dart-define. Empty means captcha UI off.
    expect(ForjaCaptcha.siteKey.isEmpty || ForjaCaptcha.isConfigured, isTrue);
    expect(ForjaCaptcha.isConfigured, ForjaCaptcha.siteKey.isNotEmpty);
  });
}
