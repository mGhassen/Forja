import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/tokens/card_quick_menu_tokens.dart';
import 'package:forja_foundation/widgets/chrome/tv_ok_hold.dart';

KeyDownEvent _down(LogicalKeyboardKey key) => KeyDownEvent(
  physicalKey: PhysicalKeyboardKey.select,
  logicalKey: key,
  timeStamp: Duration.zero,
);

KeyUpEvent _up(LogicalKeyboardKey key) => KeyUpEvent(
  physicalKey: PhysicalKeyboardKey.select,
  logicalKey: key,
  timeStamp: Duration.zero,
);

void main() {
  test('short OK runs onShort, not onHold', () {
    var short = 0;
    var hold = 0;
    final ok = TvOkHold(onHold: () => hold++);
    expect(
      ok.onKeyEvent(_down(LogicalKeyboardKey.select), onShort: () => short++),
      KeyEventResult.handled,
    );
    expect(
      ok.onKeyEvent(_up(LogicalKeyboardKey.select), onShort: () => short++),
      KeyEventResult.handled,
    );
    expect(short, 1);
    expect(hold, 0);
    ok.dispose();
  });

  test('hold OK past delay runs onHold and swallows key-up short', () async {
    var short = 0;
    var hold = 0;
    final ok = TvOkHold(
      onHold: () => hold++,
      duration: CardQuickMenuTokens.holdDelay,
    );
    expect(
      ok.onKeyEvent(_down(LogicalKeyboardKey.select), onShort: () => short++),
      KeyEventResult.handled,
    );
    await Future<void>.delayed(
      CardQuickMenuTokens.holdDelay + const Duration(milliseconds: 50),
    );
    expect(hold, 1);
    expect(
      ok.onKeyEvent(_up(LogicalKeyboardKey.select), onShort: () => short++),
      KeyEventResult.handled,
    );
    expect(short, 0);
    ok.dispose();
  });

  test('MENU key fires onHold immediately', () {
    var hold = 0;
    final ok = TvOkHold(onHold: () => hold++);
    expect(
      ok.onKeyEvent(_down(LogicalKeyboardKey.contextMenu), onShort: () {}),
      KeyEventResult.handled,
    );
    expect(hold, 1);
    ok.dispose();
  });

  test('wrapTap swallows after fireFromPointer', () {
    var tap = 0;
    var hold = 0;
    final ok = TvOkHold(onHold: () => hold++);
    final wrapped = ok.wrapTap(() => tap++);
    ok.fireFromPointer();
    expect(hold, 1);
    wrapped();
    expect(tap, 0);
    wrapped();
    expect(tap, 1);
    ok.dispose();
  });
}
