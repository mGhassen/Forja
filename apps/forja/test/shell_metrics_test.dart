import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/design/design.dart';

void main() {
  test('desktop and tv metrics differ for hero and torrent panels', () {
    const desktop = ShellMetrics.desktop;
    const tv = ShellMetrics.tv;

    expect(desktop.heroCompactRightInset, isNot(equals(tv.heroCompactRightInset)));
    expect(desktop.heroMinTitleHeight, equals(tv.heroMinTitleHeight));
    expect(desktop.heroActionUseFittedBox, isFalse);
    expect(tv.heroActionUseFittedBox, isFalse);
    expect(desktop.usesTvDensity, isFalse);
    expect(tv.usesTvDensity, isTrue);
    expect(desktop.torrentPanelPadding, lessThan(tv.torrentPanelPadding));
  });

  test('mobile metrics row exists with compact card width', () {
    expect(ShellMetrics.mobile.homeMovieCardWidth, 165);
    expect(ShellMetrics.desktop.homeMovieCardWidth, 190);
    expect(ShellMetrics.tv.homeMovieCardWidth, 220);
  });

  test('tv hub metrics use larger continue watching and title sizes', () {
    expect(ShellMetrics.tv.continueWatchingCardWidth, greaterThan(
      ShellMetrics.mobile.continueWatchingCardWidth,
    ));
    expect(ShellMetrics.tv.hubCardTitleFontSize, greaterThan(
      ShellMetrics.mobile.hubCardTitleFontSize,
    ));
  });

  test('input policies match profile expectations', () {
    expect(ShellInputPolicy.desktop.scaleOnHover, isTrue);
    expect(ShellInputPolicy.tv.scaleOnFocus, isTrue);
    expect(ShellInputPolicy.tv.wrapAppFocusTraversal, isTrue);
    expect(ShellInputPolicy.mobile.wrapAppFocusTraversal, isFalse);
  });
}
