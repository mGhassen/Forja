import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/details/hero_title.dart';

void main() {
  test('heroTitlePreferredFontSize uses leanback ladder on TV', () {
    expect(
      heroTitlePreferredFontSize(60, tvDensity: true),
      16,
    );
    expect(
      heroTitlePreferredFontSize(120, tvDensity: true),
      ShellTokens.heroFallbackTitlePreferredMaxTv,
    );
    expect(
      heroTitlePreferredFontSize(120, tvDensity: false),
      ShellTokens.heroFallbackTitlePreferredMax,
    );
    expect(
      heroTitlePreferredFontSize(120, tvDensity: true),
      lessThan(heroTitlePreferredFontSize(120, tvDensity: false)),
    );
  });

  test('heroTitleMinFontSize is denser on TV', () {
    expect(
      heroTitleMinFontSize(tvDensity: true),
      ShellTokens.heroFallbackTitleMinTv,
    );
    expect(
      heroTitleMinFontSize(tvDensity: false),
      ShellTokens.heroFallbackTitleMin,
    );
    expect(
      heroTitleMinFontSize(tvDensity: true),
      lessThan(heroTitleMinFontSize(tvDensity: false)),
    );
  });
}
