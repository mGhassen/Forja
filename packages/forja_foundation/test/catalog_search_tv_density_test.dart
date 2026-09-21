import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

void main() {
  test('hub search query uses leanback type ladder on TV', () {
    expect(
      ShellTokens.searchQueryFontSizeTv,
      ShellTokens.tvTitleFontSize,
    );
    expect(
      ShellTokens.searchQueryFontSizeTv,
      lessThan(ShellTokens.searchQueryFontSize),
    );
    expect(
      ShellTokens.searchQueryCursorHeightTv,
      lessThan(ShellTokens.searchQueryCursorHeight),
    );
  });

  test('hub search helpers use leanback type ladder on TV', () {
    expect(
      ShellTokens.searchHelperFontSizeTv,
      ShellTokens.tvBodyFontSize,
    );
    expect(
      ShellTokens.searchHelperFontSizeSelectedTv,
      ShellTokens.tvTitleFontSize,
    );
    expect(
      ShellTokens.searchHelperFontSizeTv,
      lessThan(ShellTokens.searchHelperFontSize),
    );
    expect(
      ShellTokens.searchHelperFontSizeSelectedTv,
      lessThan(ShellTokens.searchHelperFontSizeSelected),
    );
  });

  test('hub search results grid is denser on TV', () {
    expect(
      ShellTokens.searchResultsGridColumnsTv,
      greaterThan(ShellTokens.searchResultsGridColumns),
    );
    expect(
      ShellTokens.searchCardWidthTv,
      lessThan(ShellTokens.searchCardWidthDesktop),
    );
  });
}
