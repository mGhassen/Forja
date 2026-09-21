import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shell/core/forja_shell_input_policy.dart';
import 'package:forja/shell/core/forja_shell_metrics.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/tv/tv_browse_text_field.dart';
import 'package:forja/shared/player/controls/chrome/player_chrome_overlays.dart';
import 'package:forja_foundation/tokens/channel_card_tokens.dart';
import 'package:forja_foundation/tokens/forja_details_tokens.dart';
import 'package:forja_foundation/tokens/forja_settings_tokens.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/tokens/portal_list_tokens.dart';
import 'package:forja_foundation/widgets/chrome/catalog_poster_grid.dart';

void main() {
  test('tv density families: chrome scale + hand-tuned cards/hero/portals', () {
    expect(ShellTokens.tvChromeScale, 0.62);
    expect(ShellTokens.tvHeroScale, 0.80);
    expect(
      ShellTokens.posterCardWidthTv,
      closeTo(
        ShellTokens.posterCardWidthDesktop * ShellTokens.tvChromeScale,
        0.001,
      ),
    );
    expect(
      ShellTokens.tvLayoutScale,
      closeTo(ShellTokens.tvChromeScale, 0.001),
    );
    expect(
      ShellTokens.controlHeightTv,
      closeTo(ShellTokens.controlHeight * ShellTokens.tvChromeScale, 0.001),
    );
    // Channel family — hand-tuned, not mobile × chromeScale.
    expect(ShellTokens.channelCardWidthTv, ChannelCardTokens.widthTv);
    expect(ShellTokens.channelCardWidthTv, 110);
    expect(
      ShellTokens.channelCardWidthTv,
      lessThan(ShellTokens.posterCardWidthTv),
    );
    // Hero family — softer than chrome crush.
    expect(
      ShellTokens.heroMinHeightTv,
      closeTo(ShellTokens.heroMinHeightDesktop * ShellTokens.tvHeroScale, 0.001),
    );
    expect(
      ShellTokens.heroMinHeightTv,
      greaterThan(ShellTokens.heroMinHeightDesktop * ShellTokens.tvChromeScale),
    );
    // Portals family — hand row height.
    expect(PortalListTokens.rowHeightTv, 80);
    expect(
      PortalListTokens.rowHeightTv,
      greaterThan(PortalListTokens.rowHeight * ShellTokens.tvChromeScale),
    );
    // Hero CTA reserve must not crush below painted pill height.
    expect(
      ShellTokens.controlHeightTv,
      greaterThanOrEqualTo(DetailsTokens.heroPillHeightTv - 0.001),
    );
    expect(ShellTokens.tvBodyFontSize, 10);
    expect(ShellTokens.tvTitleFontSize, 12);
    expect(ShellTokens.tvMetaFontSize, 9);
    expect(SettingsTokens.sidebarWidth, 340);
    expect(SettingsTokens.sidebarWidthTv, 280);
    expect(
      DetailsTokens.sectionSpacingTv,
      closeTo(DetailsTokens.sectionSpacing * ShellTokens.tvChromeScale, 0.001),
    );
  });

  test('channelCards and poster packing fill the row', () {
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

    final channelRowW =
        channels.columns * channels.cardW + (channels.columns - 1) * gap;
    final posterRowW =
        posters.columns * posters.cardW + (posters.columns - 1) * gap;
    final inner = maxWidth - leading - trailing;
    expect(channelRowW, closeTo(inner, 0.5));
    expect(posterRowW, closeTo(inner, 0.5));
    expect(posters.cardW, greaterThan(minW));
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
      closeTo(ShellTokens.tvChromeScale, 0.001),
    );
    expect(
      tv.posterCardWidth / desktop.posterCardWidth,
      closeTo(ShellTokens.tvChromeScale, 0.001),
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

      expect(ShellInputPolicy.desktop.useFocusableMoodChips, isTrue);
      expect(desktopCentered, isFalse);
      expect(tvCentered, isFalse);
    },
  );

  testWidgets('browse-only search fields cover desktop + leanback TV',
      (tester) async {
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

    expect(desktopBrowse, isTrue);
    expect(tvBrowse, isTrue);
    expect(ShellInputPolicy.desktop.browseTextUntilActivate, isTrue);
    expect(ShellInputPolicy.tv.browseTextUntilActivate, isTrue);
    expect(ShellInputPolicy.mobile.browseTextUntilActivate, isFalse);
  });
}
