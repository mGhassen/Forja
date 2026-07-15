import 'package:flutter_test/flutter_test.dart';
import 'package:rust/src/webstreamr_settings.dart';

void main() {
  test('WebStreamr non-secret defaults are available without prefs', () {
    expect(WebStreamrSettings.defaultCountryCodes, contains('multi'));
    expect(WebStreamrSettings.defaultCountryCodes, contains('en'));
    expect(WebStreamrSettings.allExtractorIds, contains('vidsrc'));
    expect(WebStreamrSettings.allResolutions, contains('1080p'));
  });
}
