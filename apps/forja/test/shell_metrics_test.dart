import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/design/design.dart';

void main() {
  test('tv metrics are denser than desktop for leanback', () {
    const desktop = ShellMetrics.desktop;
    const tv = ShellMetrics.tv;

    expect(tv.homeMovieCardWidth, lessThan(desktop.homeMovieCardWidth));
    expect(tv.continueWatchingCardWidth, lessThan(desktop.continueWatchingCardWidth));
    expect(tv.navRailItemSpacing, lessThan(desktop.navRailItemSpacing));
    expect(desktop.usesTvDensity, isFalse);
    expect(tv.usesTvDensity, isTrue);
    expect(tv.allowCompactNavDrawer, isFalse);
  });

  test('mobile metrics row exists with compact card width', () {
    expect(ShellMetrics.mobile.homeMovieCardWidth, 165);
    expect(ShellMetrics.desktop.homeMovieCardWidth, 190);
    expect(ShellMetrics.tv.homeMovieCardWidth, 58);
  });

  test('input policies match profile expectations', () {
    expect(ShellInputPolicy.desktop.scaleOnHover, isTrue);
    expect(ShellInputPolicy.tv.scaleOnFocus, isTrue);
    expect(ShellInputPolicy.tv.wrapAppFocusTraversal, isTrue);
    expect(ShellInputPolicy.mobile.wrapAppFocusTraversal, isFalse);
  });
}
