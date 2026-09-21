import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/tokens/forja_settings_tokens.dart';

void main() {
  test('pack choice card chrome densifies on TV', () {
    expect(
      SettingsTokens.packChoiceMinHeightCompactTv,
      lessThan(SettingsTokens.packChoiceMinHeightCompact),
    );
    expect(
      SettingsTokens.packChoiceIconSizeCompactTv,
      lessThan(SettingsTokens.packChoiceIconSizeCompact),
    );
    expect(
      SettingsTokens.packChoiceRadiusCompactTv,
      lessThan(SettingsTokens.packChoiceRadiusCompact * 0.5),
    );
    expect(
      SettingsTokens.packChoiceGapCompactTv,
      lessThan(SettingsTokens.packChoiceGapCompact),
    );
    expect(
      SettingsTokens.packChoiceSectionPadTv.bottom,
      lessThan(SettingsTokens.packChoiceSectionPad.bottom),
    );
  });
}
