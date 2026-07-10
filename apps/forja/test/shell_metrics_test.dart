import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/design/design.dart';

void main() {
  test('tv visual metrics match desktop; usesTvDensity marks profile only', () {
    const desktop = ShellMetrics.desktop;
    const tv = ShellMetrics.tv;

    expect(tv.homeMovieCardWidth, equals(desktop.homeMovieCardWidth));
    expect(tv.continueWatchingCardWidth, equals(desktop.continueWatchingCardWidth));
    expect(tv.hubCardTitleFontSize, equals(desktop.hubCardTitleFontSize));
    expect(tv.heroCompactRightInset, equals(desktop.heroCompactRightInset));
    expect(tv.torrentPanelPadding, equals(desktop.torrentPanelPadding));
    expect(tv.navRailItemSpacing, equals(desktop.navRailItemSpacing));
    expect(desktop.usesTvDensity, isFalse);
    expect(tv.usesTvDensity, isTrue);
  });

  test('mobile metrics row exists with compact card width', () {
    expect(ShellMetrics.mobile.homeMovieCardWidth, 165);
    expect(ShellMetrics.desktop.homeMovieCardWidth, 190);
    expect(ShellMetrics.tv.homeMovieCardWidth, 190);
  });

  test('input policies match profile expectations', () {
    expect(ShellInputPolicy.desktop.scaleOnHover, isTrue);
    expect(ShellInputPolicy.tv.scaleOnFocus, isTrue);
    expect(ShellInputPolicy.tv.wrapAppFocusTraversal, isTrue);
    expect(ShellInputPolicy.mobile.wrapAppFocusTraversal, isFalse);
  });
}
