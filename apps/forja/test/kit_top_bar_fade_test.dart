import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shell/chrome/kit_top_bar_fade.dart';

void main() {
  group('kitTopBarHideProgress', () {
    // heroHeight = hero text-column bottom (title → CTA row).
    // hideStart = heroHeight − barHeight − slideDistance = 700 − 48 − 56 = 596.
    test('painted while the hero chrome is still clear of the bar', () {
      expect(
        kitTopBarHideProgress(scrollOffset: 0, heroHeight: 700, barHeight: 48),
        0,
      );
      expect(
        kitTopBarHideProgress(
          scrollOffset: 596,
          heroHeight: 700,
          barHeight: 48,
          slideDistance: 56,
        ),
        0,
      );
    });

    test('slides out over the slide distance ahead of the hero chrome', () {
      expect(
        kitTopBarHideProgress(
          scrollOffset: 596 + 28,
          heroHeight: 700,
          barHeight: 48,
          slideDistance: 56,
        ),
        closeTo(0.5, 1e-9),
      );
      expect(
        kitTopBarHideProgress(
          scrollOffset: 596 + 56,
          heroHeight: 700,
          barHeight: 48,
          slideDistance: 56,
        ),
        1,
      );
      expect(
        kitTopBarHideProgress(
          scrollOffset: 5000,
          heroHeight: 700,
          barHeight: 48,
        ),
        1,
      );
    });

    test('fully hidden exactly when the chrome edge meets the bar bottom', () {
      const hero = 700.0;
      const bar = 48.0;
      // Chrome edge on screen = heroHeight − scrollOffset = barHeight.
      expect(
        kitTopBarHideProgress(
          scrollOffset: hero - bar,
          heroHeight: hero,
          barHeight: bar,
          slideDistance: 56,
        ),
        1,
      );
    });

    test('lifted bar never overlaps the hero chrome mid-slide', () {
      const hero = 700.0;
      const bar = 48.0;
      const slide = 56.0;
      for (var offset = 0.0; offset <= hero; offset += 4) {
        final p = kitTopBarHideProgress(
          scrollOffset: offset,
          heroHeight: hero,
          barHeight: bar,
          slideDistance: slide,
        );
        final barBottomOnScreen = bar * (1 - p);
        final chromeEdgeOnScreen = hero - offset;
        if (chromeEdgeOnScreen < 0) break;
        expect(
          barBottomOnScreen,
          lessThanOrEqualTo(chromeEdgeOnScreen + 1e-9),
          reason:
              'offset $offset: bar bottom $barBottomOnScreen vs chrome '
              '$chromeEdgeOnScreen',
        );
      }
    });

    test('no hero → never hides', () {
      expect(
        kitTopBarHideProgress(scrollOffset: 900, heroHeight: 0, barHeight: 48),
        0,
      );
    });

    test('text-column bottom hides the menu before CTA pills reach it', () {
      // Synthetic TV-like page: 972 backdrop; text column ends at 600; the
      // bleed rail starts at 740. A lower-row reveal scrolls the page so the
      // CTA row's bottom edge meets the bar's bottom edge.
      const backdrop = 972.0;
      const railTop = 740.0;
      const chromeBottom = 600.0;
      const bar = 48.0;
      const ctaUnderBar = chromeBottom - bar;
      expect(
        kitTopBarHideProgress(
          scrollOffset: ctaUnderBar,
          heroHeight: backdrop,
          barHeight: bar,
        ),
        0,
        reason: 'full-backdrop height keeps the menu over the pills',
      );
      expect(
        kitTopBarHideProgress(
          scrollOffset: ctaUnderBar,
          heroHeight: railTop,
          barHeight: bar,
        ),
        lessThan(1),
        reason: 'band-above-rail height is only part way',
      );
      expect(
        kitTopBarHideProgress(
          scrollOffset: ctaUnderBar,
          heroHeight: chromeBottom,
          barHeight: bar,
        ),
        1,
        reason: 'text-column bottom has the menu gone',
      );
    });
  });

  group('kitTopBarScrimOpacity', () {
    test('no scrim at rest', () {
      expect(kitTopBarScrimOpacity(scrollOffset: 0, hideProgress: 0), 0);
    });

    test('fades in with scroll, full once past the fade distance', () {
      expect(
        kitTopBarScrimOpacity(
          scrollOffset: 28,
          hideProgress: 0,
          fadeInDistance: 56,
        ),
        closeTo(0.5, 1e-9),
      );
      expect(
        kitTopBarScrimOpacity(
          scrollOffset: 400,
          hideProgress: 0,
          fadeInDistance: 56,
        ),
        1,
      );
    });

    test('fades out with the bar', () {
      expect(
        kitTopBarScrimOpacity(scrollOffset: 900, hideProgress: 0.75),
        closeTo(0.25, 1e-9),
      );
      expect(kitTopBarScrimOpacity(scrollOffset: 900, hideProgress: 1), 0);
    });

    test('hero-less hub keeps the scrim while scrolled', () {
      final hide = kitTopBarHideProgress(
        scrollOffset: 600,
        heroHeight: 0,
        barHeight: 48,
      );
      expect(kitTopBarScrimOpacity(scrollOffset: 600, hideProgress: hide), 1);
    });
  });
}
