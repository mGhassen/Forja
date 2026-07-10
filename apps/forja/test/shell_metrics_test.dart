import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/design/design.dart';

void main() {
  test('desktop and tv metrics differ for hero and torrent panels', () {
    const desktop = ShellMetrics.desktop;
    const tv = ShellMetrics.tv;

    expect(desktop.heroCompactRightInset, isNot(equals(tv.heroCompactRightInset)));
    expect(desktop.heroMinTitleHeight, greaterThan(tv.heroMinTitleHeight));
    expect(desktop.heroActionUseFittedBox, isFalse);
    expect(tv.heroActionUseFittedBox, isTrue);
    expect(desktop.usesTvDensity, isFalse);
    expect(tv.usesTvDensity, isTrue);
    expect(desktop.torrentPanelPadding, lessThan(tv.torrentPanelPadding));
  });

  test('mobile metrics row exists with compact card width', () {
    expect(ShellMetrics.mobile.homeMovieCardWidth, 165);
    expect(ShellMetrics.desktop.homeMovieCardWidth, 190);
    expect(ShellMetrics.tv.homeMovieCardWidth, 220);
  });

  test('input policies match profile expectations', () {
    expect(ShellInputPolicy.desktop.scaleOnHover, isTrue);
    expect(ShellInputPolicy.desktop.showFocusRing, isFalse);
    expect(ShellInputPolicy.tv.showFocusRing, isTrue);
    expect(ShellInputPolicy.tv.wrapAppFocusTraversal, isTrue);
    expect(ShellInputPolicy.mobile.wrapAppFocusTraversal, isFalse);
  });
}
