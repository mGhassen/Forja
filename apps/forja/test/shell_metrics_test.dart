import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shell/core/forja_shell_input_policy.dart';
import 'package:forja/shell/core/forja_shell_metrics.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/tv/tv_browse_text_field.dart';
import 'package:forja/shared/player/controls/chrome/player_chrome_overlays.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/catalog_poster_grid.dart';

void main() {
  test('tv layout scale is iso-desktop 0.85', () {
    expect(ShellTokens.tvLayoutScale, 0.85);
    expect(
      ShellTokens.posterCardWidthTv,
      closeTo(ShellTokens.posterCardWidthDesktop * ShellTokens.tvLayoutScale, 0.001),
    );
    expect(
      ShellTokens.tvPosterCardRowGap,
      closeTo(ShellTokens.posterCardRowGap * ShellTokens.tvLayoutScale, 0.001),
    );
    expect(
      ShellTokens.tvHomeRowSpacing,
      closeTo(ShellTokens.homeRowSpacing * ShellTokens.tvLayoutScale, 0.001),
    );
    expect(
      ShellTokens.continueWatchingCardWidthTv,
      closeTo(
        ShellTokens.shellContinueWatchingCardWidthDesktop *
            ShellTokens.tvLayoutScale,
        0.001,
      ),
    );
    expect(
      ShellTokens.navRailWidthTv /
          ShellTokens.navRailWidth,
      closeTo(ShellTokens.tvLayoutScale, 0.001),
    );
  });

  test('channelCards packing fills row — not fixed poster cells', () {
    const maxWidth = 960.0;
    const minW = 140.0;
    const minH = 140.0;
    const gap = 10.0;
    const leading = 8.0;
    const trailing = 12.0;

    final channels = CatalogPosterGridLayout.channelCards(
      maxWidth: maxWidth,
      minW: minW,
      minH: minH,
      gap: gap,
      leading: leading,
      trailing: trailing,
    );
    final posters = CatalogPosterGridLayout.poster(
      maxWidth: maxWidth,
      cardW: minW,
      cardH: minH,
      gap: gap,
      leading: leading,
      trailing: trailing,
    );

    // Channel packing stretches cells to fill the inner width.
    final channelRowW =
        channels.columns * channels.cardW + (channels.columns - 1) * gap;
    final posterRowW =
        posters.columns * posters.cardW + (posters.columns - 1) * gap;
    final inner = maxWidth - leading - trailing;
    expect(channelRowW, closeTo(inner, 0.5));
    expect(posterRowW, lessThan(inner));
    expect(channels.cardW, isNot(equals(posters.cardW)));
  });

  test('tv metrics are denser than desktop for leanback', () {
    const desktop = ShellMetrics.desktop;
    const tv = ShellMetrics.tv;

    expect(tv.posterCardWidth, lessThan(desktop.posterCardWidth));
    expect(tv.navRailWidth, lessThan(desktop.navRailWidth));
    expect(tv.navRailLogoWidth, lessThan(desktop.navRailLogoWidth));
    expect(tv.navRailItemSpacing, lessThan(desktop.navRailItemSpacing));
    expect(
      tv.navRailWidth / desktop.navRailWidth,
      closeTo(tv.posterCardWidth / desktop.posterCardWidth, 0.001),
    );
    expect(desktop.usesTvDensity, isFalse);
    expect(tv.usesTvDensity, isTrue);
    expect(tv.allowCompactNavDrawer, isFalse);
  });

  test('mobile metrics row exists with compact card width', () {
    expect(ShellMetrics.mobile.posterCardWidth, ShellTokens.posterCardWidthMobile);
    expect(ShellMetrics.desktop.posterCardWidth, ShellTokens.posterCardWidthDesktop);
    expect(ShellMetrics.tv.posterCardWidth, ShellTokens.posterCardWidthTv);
  });

  test('input policies match profile expectations', () {
    // Desktop: hover + D-pad + Ken Burns. TV: D-pad, no hover / Ken Burns.
    expect(ShellInputPolicy.desktop.scaleOnHover, isTrue);
    expect(ShellInputPolicy.desktop.scaleOnFocus, isTrue);
    expect(ShellInputPolicy.desktop.wrapAppFocusTraversal, isTrue);
    expect(ShellInputPolicy.desktop.useFocusableMoodChips, isTrue);
    expect(ShellInputPolicy.desktop.leanbackOnly, isFalse);
    expect(ShellInputPolicy.tv.leanbackOnly, isTrue);
    expect(ShellInputPolicy.mobile.leanbackOnly, isFalse);
    expect(ShellInputPolicy.desktop.instantFocusChrome, isFalse);
    expect(ShellInputPolicy.tv.scaleOnHover, isFalse);
    expect(ShellInputPolicy.tv.scaleOnFocus, isTrue);
    expect(ShellInputPolicy.tv.wrapAppFocusTraversal, isTrue);
    expect(ShellInputPolicy.tv.kenBurnsBackdrop, isFalse);
    expect(ShellInputPolicy.tv.instantFocusChrome, isTrue);
    expect(ShellInputPolicy.mobile.wrapAppFocusTraversal, isFalse);

    final desktopCfg = shellPlatformConfigFor(ShellProfile.desktop);
    expect(desktopCfg.metrics, ShellMetrics.desktop);
    expect(desktopCfg.inputPolicy, ShellInputPolicy.desktop);
    expect(desktopCfg.chromeKind, ShellChromeKind.navRail);
  });

  testWidgets(
    'player floating menus never force centered layout on TV',
    (tester) async {
      late bool desktopCentered;
      late bool tvCentered;

      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              ShellScope(
                profile: ShellProfile.desktop,
                config: shellPlatformConfigFor(ShellProfile.desktop),
                child: Builder(
                  builder: (context) {
                    desktopCentered = playerTvUsesCenteredDialogs(context);
                    return const SizedBox.shrink();
                  },
                ),
              ),
              ShellScope(
                profile: ShellProfile.tv,
                config: shellPlatformConfigFor(ShellProfile.tv),
                child: Builder(
                  builder: (context) {
                    tvCentered = playerTvUsesCenteredDialogs(context);
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        ),
      );

      // ATV floating menus match desktop (anchored) — never force centered.
      expect(ShellInputPolicy.desktop.useFocusableMoodChips, isTrue);
      expect(desktopCentered, isFalse);
      expect(tvCentered, isFalse);
    },
  );

  testWidgets('browse-only search fields are leanback TV only', (tester) async {
    late bool desktopBrowse;
    late bool tvBrowse;

    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            ShellScope(
              profile: ShellProfile.desktop,
              config: shellPlatformConfigFor(ShellProfile.desktop),
              child: Builder(
                builder: (context) {
                  desktopBrowse = shellTvBrowseSearch(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
            ShellScope(
              profile: ShellProfile.tv,
              config: shellPlatformConfigFor(ShellProfile.tv),
              child: Builder(
                builder: (context) {
                  tvBrowse = shellTvBrowseSearch(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );

    expect(desktopBrowse, isFalse);
    expect(tvBrowse, isTrue);
  });
}
