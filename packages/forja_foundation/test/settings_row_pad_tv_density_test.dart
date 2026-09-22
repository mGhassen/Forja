import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/tokens/forja_settings_tokens.dart';

void main() {
  test('Settings toggle / chip row chrome densifies on TV', () {
    expect(SettingsTokens.rowPadVTv, lessThan(SettingsTokens.rowPadV));
    expect(
      SettingsTokens.rowTitleSubtitleGapTv,
      lessThan(SettingsTokens.rowTitleSubtitleGap),
    );
    expect(
      SettingsTokens.categoryChipStripPadTv.vertical,
      lessThan(SettingsTokens.categoryChipStripPad.vertical),
    );
    expect(
      SettingsTokens.categoryChipGapTv,
      lessThan(SettingsTokens.categoryChipGap),
    );
    expect(
      SettingsTokens.expandHeaderPadVTv,
      lessThan(SettingsTokens.expandHeaderPadV),
    );
    expect(
      SettingsTokens.expandChildrenPadTv.bottom,
      lessThan(SettingsTokens.expandChildrenPad.bottom),
    );
  });

  test('Addons master list rows are roomier than dense toggle rows', () {
    expect(SettingsTokens.addonListRowPadV, greaterThan(SettingsTokens.rowPadV));
    expect(
      SettingsTokens.addonListRowPadVTv,
      greaterThan(SettingsTokens.rowPadVTv),
    );
    expect(SettingsTokens.addonListSeparatorHeight, greaterThan(1));
    expect(
      SettingsTokens.addonListSeparatorHeightTv,
      lessThan(SettingsTokens.addonListSeparatorHeight),
    );
  });
}
