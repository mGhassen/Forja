import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/utils/hero_desktop_layout.dart';

void main() {
  const minTitle = ShellTokens.heroMinTitleHeightDesktop;

  double paintedHeight(HeroDesktopTextLayout fit, {double reserved = 0}) {
    const titleGap = ShellTokens.heroTitleMetaGapDesktop;
    const metaH = ShellTokens.heroMetaSlotHeightDesktop;
    const actionGap = ShellTokens.heroMetaActionsGapDesktop;
    const metaGap = ShellTokens.heroMetaOverviewGapDesktop;
    final overview = fit.showOverview
        ? metaGap + fit.overviewSlotHeight
        : 0.0;
    final meta = fit.showMeta ? titleGap + metaH : 0.0;
    final actions =
        fit.actionRowHeight > 0 ? actionGap + fit.actionRowHeight : 0.0;
    return fit.titleHeight + meta + overview + actions + reserved;
  }

  test('ample height keeps full title slot and overview', () {
    final fit = heroDesktopTextLayout(
      maxHeight: 600,
      hasOverview: true,
      minTitleHeight: minTitle,
    );
    expect(fit.showOverview, isTrue);
    expect(fit.showMeta, isTrue);
    expect(fit.titleHeight, ShellTokens.heroTitleSlotHeightDesktop);
    expect(fit.overviewMaxLines, ShellTokens.heroOverviewMaxLinesDesktop);
    expect(fit.actionRowHeight, ShellTokens.shellButtonHeight);
  });

  test('tight bleed band never exceeds maxHeight', () {
    // Matches the emulator overflow: ~92px text band above Featured.
    const maxHeight = 91.8;
    final fit = heroDesktopTextLayout(
      maxHeight: maxHeight,
      hasOverview: true,
      minTitleHeight: minTitle,
    );
    expect(paintedHeight(fit), lessThanOrEqualTo(maxHeight + 0.01));
    expect(fit.showOverview, isFalse);
    expect(fit.titleHeight, lessThan(minTitle));
  });

  test('title may shrink below minTitleHeight to fit chrome', () {
    final base = ShellTokens.heroTitleMetaGapDesktop +
        ShellTokens.heroMetaSlotHeightDesktop +
        ShellTokens.heroMetaActionsGapDesktop +
        ShellTokens.shellButtonHeight;
    final maxHeight = base + minTitle - 20;
    final fit = heroDesktopTextLayout(
      maxHeight: maxHeight,
      hasOverview: false,
      minTitleHeight: minTitle,
    );
    expect(fit.titleHeight, lessThan(minTitle));
    expect(fit.titleHeight, greaterThanOrEqualTo(0));
    expect(paintedHeight(fit), lessThanOrEqualTo(maxHeight + 0.01));
  });

  test('chrome taller than maxHeight yields zero title', () {
    const maxHeight = 50.0;
    final fit = heroDesktopTextLayout(
      maxHeight: maxHeight,
      hasOverview: true,
      minTitleHeight: minTitle,
    );
    expect(fit.titleHeight, 0);
    expect(fit.showOverview, isFalse);
    expect(fit.showMeta, isFalse);
    expect(paintedHeight(fit), lessThanOrEqualTo(maxHeight + 0.01));
  });
}
