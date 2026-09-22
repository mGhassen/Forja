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
    // Film family — denser than × chromeScale; chrome stays on tvChromeScale.
    expect(ShellTokens.posterCardWidthTv, 100);
    expect(
      ShellTokens.posterCardWidthTv,
      lessThan(ShellTokens.posterCardWidthDesktop * ShellTokens.tvChromeScale),
    );
    // Score chip — desktop stays readable; TV uses the dense type ladder.
    expect(ShellTokens.posterRatingFontSize, 11);
    expect(ShellTokens.posterRatingIconSize, 12);
    expect(
      ShellTokens.posterRatingFontSize,
      greaterThan(ShellTokens.posterRatingFontSizeTv),
    );
    expect(
      ShellTokens.posterRatingIconSize,
      greaterThan(ShellTokens.posterRatingIconSizeTv),
    );
    expect(
      ShellTokens.tvLayoutScale,
      closeTo(
        ShellTokens.posterCardWidthTv / ShellTokens.posterCardWidthDesktop,
        0.001,
      ),
    );
    expect(
      ShellTokens.navRailWidthTv,
      closeTo(ShellTokens.navRailWidth * ShellTokens.tvChromeScale, 0.001),
    );
    expect(
      ShellTokens.controlHeightTv,
      closeTo(ShellTokens.controlHeight * ShellTokens.tvChromeScale, 0.001),
    );
    // Sources provider chips — H matches action chips; V is a leanback hit target.
    expect(
      ShellTokens.torrentPanelChipPadHTv,
      ShellTokens.actionChipPadHTv,
    );
    expect(ShellTokens.torrentPanelChipPadVTv, 6);
    expect(
      ShellTokens.torrentPanelChipPadVTv,
      lessThan(ShellTokens.torrentPanelChipPadVDesktop),
    );
    expect(
      ShellTokens.torrentPanelChipFontSizeTv,
      ShellTokens.tvMetaFontSize,
    );
    expect(
      ShellTokens.torrentPanelMetaFontSizeTv,
      ShellTokens.tvMetaFontSize,
    );
    expect(
      ShellTokens.torrentPanelMetaIconSizeTv,
      ShellTokens.actionChipIconSizeTv,
    );
    expect(
      ShellTokens.torrentPanelLeadingIconSizeTv,
      closeTo(
        ShellTokens.torrentPanelLeadingIconSizeDesktop *
            ShellTokens.tvChromeScale,
        0.001,
      ),
    );
    expect(
      ShellTokens.torrentPanelPaddingTv,
      closeTo(
        ShellTokens.torrentPanelPaddingDesktop * ShellTokens.tvChromeScale,
        0.001,
      ),
    );
    expect(
      ShellTokens.playerStatusCardMaxWidthTv,
      closeTo(
        ShellTokens.playerStatusCardMaxWidth * ShellTokens.tvChromeScale,
        0.001,
      ),
    );
    expect(
      ShellTokens.playerStatusLabelFontSizeTv,
      ShellTokens.tvTitleFontSize,
    );
    expect(
      ShellTokens.playerStatusHeaderFontSizeTv,
      ShellTokens.tvMetaFontSize,
    );
    expect(
      ShellTokens.streamLoadingHeadlineFontSizeTv,
      ShellTokens.tvTitleFontSize,
    );
    expect(
      ShellTokens.streamLoadingHintFontSizeTv,
      ShellTokens.tvBodyFontSize,
    );
    expect(
      ShellTokens.streamLoadingCancelFontSizeTv,
      ShellTokens.tvBodyFontSize,
    );
    expect(
      ShellTokens.streamLoadingStatusStripReserveTv,
      closeTo(
        ShellTokens.streamLoadingStatusStripReserve * ShellTokens.tvChromeScale,
        0.001,
      ),
    );
    expect(
      ShellTokens.streamLoadingProviderListMaxWidthTv,
      closeTo(
        ShellTokens.streamLoadingProviderListMaxWidth *
            ShellTokens.tvChromeScale,
        0.001,
      ),
    );
    expect(
      ShellTokens.streamLoadingFailureTitleFontSizeTv,
      ShellTokens.tvTitleFontSize,
    );
    expect(
      DetailsTokens.sourcesPanelPaddingTv.left,
      closeTo(
        DetailsTokens.sourcesPanelPadding.left * ShellTokens.tvChromeScale,
        0.001,
      ),
    );
    // Nav profile — same boost as desktop (TV icons already chrome-scaled).
    expect(
      ShellTokens.navRailProfileAvatarScaleTv,
      ShellTokens.navRailProfileAvatarScaleDesktop,
    );
    // Channel family — hand-tuned logo face (not film poster width).
    expect(ShellTokens.channelCardWidthTv, ChannelCardTokens.widthTv);
    expect(ShellTokens.channelCardWidthTv, 110);
    // Hero family — softer than chrome crush.
    expect(
      ShellTokens.heroMinHeightTv,
      closeTo(ShellTokens.heroMinHeightDesktop * ShellTokens.tvHeroScale, 0.001),
    );
    expect(
      ShellTokens.heroMinHeightTv,
      greaterThan(ShellTokens.heroMinHeightDesktop * ShellTokens.tvChromeScale),
    );
    // Portals family — hand row height (denser than desktop, not × chrome).
    expect(PortalListTokens.rowHeightTv, 72);
    expect(
      PortalListTokens.rowHeightTv,
      lessThan(PortalListTokens.rowHeight),
    );
    expect(
      PortalListTokens.headerIconSizeTv,
      closeTo(
        PortalListTokens.headerIconSize * ShellTokens.tvChromeScale,
        0.001,
      ),
    );
    expect(
      PortalListTokens.searchFieldHeightTv,
      ShellTokens.eventSearchCollapsedTv,
    );
    expect(
      PortalListTokens.searchPrefixIconSizeTv,
      ShellTokens.eventSearchClearIconSizeTv,
    );
    expect(PortalListTokens.searchFieldHeightTv, lessThan(48));
    expect(
      PortalListTokens.resolvePanelWidth(true, ShellTokens.sidePanelWidth),
      ShellTokens.sidePanelWidthTv,
    );
    expect(
      PortalListTokens.resolveRowHeight(true, PortalListTokens.rowHeight),
      PortalListTokens.rowHeightTv,
    );
    // Hero CTA reserve must not crush below painted pill height.
    expect(
      ShellTokens.controlHeightTv,
      greaterThanOrEqualTo(DetailsTokens.heroPillHeightTv - 0.001),
    );
    expect(ShellTokens.tvBodyFontSize, 9);
    expect(ShellTokens.tvTitleFontSize, 11);
    expect(ShellTokens.tvMetaFontSize, 8);
    expect(SettingsTokens.sidebarWidth, 280);
    expect(SettingsTokens.sidebarWidthTv, 240);
    expect(SettingsTokens.detailMaxWidthTv, lessThan(SettingsTokens.detailMaxWidth));
    expect(SettingsTokens.detailMaxWidthTv, 480);
    // Settings roles → shell ladder (title / body / meta) — no parallel scale.
    expect(SettingsTokens.hubTitleSizeTv, ShellTokens.tvTitleFontSize);
    expect(SettingsTokens.pageTitleSizeTv, ShellTokens.tvTitleFontSize);
    expect(SettingsTokens.categoryTitleSizeTv, ShellTokens.tvBodyFontSize);
    expect(SettingsTokens.rowTitleSizeTv, ShellTokens.tvBodyFontSize);
    expect(SettingsTokens.categorySubtitleSizeTv, ShellTokens.tvMetaFontSize);
    expect(SettingsTokens.rowSubtitleSizeTv, ShellTokens.tvMetaFontSize);
    expect(SettingsTokens.groupLabelSizeTv, ShellTokens.tvMetaFontSize);
    expect(
      SettingsTokens.categoryTitleSizeTv,
      greaterThan(SettingsTokens.categorySubtitleSizeTv),
    );
    expect(
      SettingsTokens.filledButtonHeightTv,
      lessThan(SettingsTokens.filledButtonHeight),
    );
    expect(
      SettingsTokens.filledButtonHeightTv,
      greaterThan(
        SettingsTokens.filledButtonHeight * ShellTokens.tvChromeScale,
      ),
    );
    expect(
      SettingsTokens.iconButtonHitSizeTv,
      closeTo(
        SettingsTokens.iconButtonHitSize * ShellTokens.tvChromeScale,
        0.001,
      ),
    );
    expect(
      SettingsTokens.textFieldPadTopTv,
      closeTo(
        SettingsTokens.textFieldPadTop * ShellTokens.tvChromeScale,
        0.001,
      ),
    );
    expect(
      ShellTokens.formInputFontSizeTv,
      ShellTokens.tvBodyFontSize,
    );
    expect(
      ShellTokens.formInputHintFontSizeTv,
      ShellTokens.tvMetaFontSize,
    );
    expect(
      ShellTokens.formInputIconSizeTv,
      closeTo(
        ShellTokens.formInputIconSize * ShellTokens.tvChromeScale,
        0.001,
      ),
    );
    expect(SettingsTokens.sliderThumbRadiusTv, 5);
    expect(
      SettingsTokens.sliderThumbRadiusTv,
      lessThan(SettingsTokens.sliderThumbRadius),
    );
    expect(SettingsTokens.dialogMaxWidthCapTv, 360);
    expect(SettingsTokens.dialogMaxWidthCap, 440);
    expect(
      SettingsTokens.dialogMaxWidthCapTv,
      lessThan(SettingsTokens.dialogMaxWidthCap),
    );
    expect(SettingsTokens.dialogCheckSizeTv, lessThan(SettingsTokens.dialogCheckSize));
    expect(
      SettingsTokens.dialogOptionPadVTv,
      closeTo(
        SettingsTokens.dialogOptionPadV * ShellTokens.tvChromeScale,
        0.001,
      ),
    );
    expect(
      DetailsTokens.sectionSpacingTv,
      closeTo(DetailsTokens.sectionSpacing * ShellTokens.tvChromeScale, 0.001),
    );
    expect(
      DetailsTokens.backIconSizeTv,
      closeTo(DetailsTokens.backIconSize * ShellTokens.tvChromeScale, 0.001),
    );
    expect(
      DetailsTokens.backHitSizeOf(true),
      closeTo(
        DetailsTokens.backIconSizeTv + DetailsTokens.backHitPadTv,
        0.001,
      ),
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
      closeTo(ShellTokens.tvLayoutScale, 0.001),
    );
    expect(tv.posterCardWidth, ShellTokens.posterCardWidthTv);
    expect(desktop.usesTvDensity, isFalse);
    expect(tv.usesTvDensity, isTrue);
    expect(tv.allowCompactNavDrawer, isFalse);
    expect(
      tv.torrentPanelRowTitleFontSize,
      lessThan(desktop.torrentPanelRowTitleFontSize),
    );
    expect(tv.torrentPanelRowPadV, lessThan(desktop.torrentPanelRowPadV));
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

  testWidgets('browse-only text fields are leanback TV only', (tester) async {
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
    expect(ShellInputPolicy.desktop.browseTextUntilActivate, isFalse);
    expect(ShellInputPolicy.tv.browseTextUntilActivate, isTrue);
    expect(ShellInputPolicy.mobile.browseTextUntilActivate, isFalse);
  });
}
