import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/catalog/cinematic_hero.dart';

void main() {
  group('CinematicHeroState.textColumnBottomInset', () {
    test('no bleed row → only the column breathing room', () {
      const layout = CinematicHeroLayout();
      expect(
        CinematicHeroState.textColumnBottomInset(layout, pageBleed: false),
        layout.scaledChrome(16, floor: 8.0, ceil: 16.0),
      );
    });

    test('bleed row → rail region + breathing room', () {
      const layout = CinematicHeroLayout(
        firstCatalogRowHeight: 200,
        bleedDownOffset: 40,
      );
      expect(
        CinematicHeroState.textColumnBottomInset(layout, pageBleed: true),
        200 +
            ShellTokens.homePageBottomSectionTopPadding +
            40 +
            layout.scaledChrome(16, floor: 8.0, ceil: 16.0),
      );
    });
  });

  group('CinematicHeroState.chromeFadeHeight', () {
    test('no bleed row → text column bottom below top bar bleed', () {
      const layout = CinematicHeroLayout(topBarBleed: 10);
      expect(
        CinematicHeroState.chromeFadeHeight(
          imageHeight: 600,
          layout: layout,
          pageBleed: false,
        ),
        610 -
            CinematicHeroState.textColumnBottomInset(layout, pageBleed: false),
      );
    });

    test('bleed row → text column bottom above the rail region', () {
      const layout = CinematicHeroLayout(
        firstCatalogRowHeight: 200,
        bleedDownOffset: 40,
        scale: 1,
      );
      final inset = CinematicHeroState.textColumnBottomInset(
        layout,
        pageBleed: true,
      );
      final h = CinematicHeroState.chromeFadeHeight(
        imageHeight: 600,
        layout: layout,
        pageBleed: true,
      );
      expect(h, 600 - inset);
      expect(h, lessThan(600 - (200 + 40)), reason: 'above the rail region');
    });

    test('rail taller than the backdrop clamps to zero', () {
      const layout = CinematicHeroLayout(
        firstCatalogRowHeight: 900,
        bleedDownOffset: 0,
      );
      expect(
        CinematicHeroState.chromeFadeHeight(
          imageHeight: 300,
          layout: layout,
          pageBleed: true,
        ),
        0,
      );
    });

    test('TV density scales the insets like the hero paint does', () {
      const layout = CinematicHeroLayout(
        tvDensity: true,
        scale: 0.5,
        firstCatalogRowHeight: 100,
      );
      final inset =
          100 +
          layout.scaledChrome(ShellTokens.homePageBottomSectionTopPadding) +
          layout.resolvedBleedDownOffset +
          layout.scaledChrome(16, floor: 8.0, ceil: 16.0);
      expect(
        CinematicHeroState.chromeFadeHeight(
          imageHeight: 800,
          layout: layout,
          pageBleed: true,
        ),
        800 - inset,
      );
    });
  });

  testWidgets('onHeight reports the text-column bottom above a bleed row', (
    tester,
  ) async {
    double? reported;
    const imageHeight = 600.0;
    const layout = CinematicHeroLayout(
      kenBurns: false,
      compact: false,
      firstCatalogRowHeight: 150,
      bleedDownOffset: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1400,
            height: 900,
            child: CinematicHero(
              height: imageHeight,
              slides: const [
                CinematicHeroSlide(
                  id: 'a',
                  title: 'Alpha',
                  backdropUrl: 'https://example.com/a.jpg',
                  overview: 'First',
                ),
              ],
              layout: layout,
              pageBottomChild: const SizedBox(height: 150),
              onHeight: (h) => reported = h,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(reported, isNotNull);
    expect(
      reported,
      CinematicHeroState.chromeFadeHeight(
        imageHeight: imageHeight,
        layout: layout,
        pageBleed: true,
      ),
    );
    expect(reported, lessThan(imageHeight - 150), reason: 'above the rail');
  });

  testWidgets('onHeight reports the text-column bottom without a bleed row', (
    tester,
  ) async {
    double? reported;
    const layout = CinematicHeroLayout(kenBurns: false, compact: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 500,
            child: CinematicHero(
              height: 420,
              slides: const [
                CinematicHeroSlide(
                  id: 'a',
                  title: 'Alpha',
                  backdropUrl: 'https://example.com/a.jpg',
                ),
              ],
              layout: layout,
              onHeight: (h) => reported = h,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(
      reported,
      420 - CinematicHeroState.textColumnBottomInset(layout, pageBleed: false),
    );
  });
}
