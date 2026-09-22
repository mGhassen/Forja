import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

void main() {
  test('Hub search filter lens chrome densifies on TV', () {
    expect(
      ShellTokens.searchFilterScoreTrackHeightTv,
      lessThan(ShellTokens.searchFilterScoreTrackHeight),
    );
    expect(
      ShellTokens.searchFilterYearTrackHeightTv,
      lessThan(ShellTokens.searchFilterYearTrackHeight),
    );
    expect(
      ShellTokens.searchFilterGhostChipPadHTv,
      lessThan(ShellTokens.searchFilterGhostChipPadH),
    );
    expect(
      ShellTokens.searchFilterSubmitPadVTv,
      lessThan(ShellTokens.searchFilterSubmitPadV),
    );
    expect(
      ShellTokens.searchFilterBlockGapTv,
      lessThan(ShellTokens.searchFilterBlockGap),
    );
    expect(
      ShellTokens.searchFilterSectionLabelFontSizeTv,
      equals(ShellTokens.tvMetaFontSize),
    );
    expect(
      ShellTokens.searchFilterGhostChipFontSizeTv,
      equals(ShellTokens.tvBodyFontSize),
    );
  });
}
