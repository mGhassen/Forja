import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/blocks/shell/shell_nav_placement.dart';

void main() {
  test('LTR reserves the rail on the left', () {
    const placement = ShellNavPlacement.ltr;
    final pad = placement.contentPadding(
      railWidth: 120,
      safeLeft: 8,
      safeRight: 4,
    );
    expect(placement.railOnRight, isFalse);
    expect(pad.left, 128);
    expect(pad.right, 4);
    expect(placement.isTowardPage(LogicalKeyboardKey.arrowRight), isTrue);
    expect(placement.isAwayFromPage(LogicalKeyboardKey.arrowLeft), isTrue);
  });

  test('RTL reserves the rail on the right', () {
    const placement = ShellNavPlacement(textDirection: TextDirection.rtl);
    final pad = placement.contentPadding(
      railWidth: 120,
      safeLeft: 8,
      safeRight: 4,
    );
    expect(placement.railOnRight, isTrue);
    expect(pad.left, 8);
    expect(pad.right, 124);
    expect(placement.isTowardPage(LogicalKeyboardKey.arrowLeft), isTrue);
    expect(placement.isAwayFromPage(LogicalKeyboardKey.arrowRight), isTrue);
    final menu = placement.compactMenuPadding(leading: 12, top: 6);
    expect(menu.right, 12);
    expect(menu.left, 0);
  });
}
