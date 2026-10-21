import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shell/tv/shell_tv_hold_accel.dart';

KeyEvent _down(LogicalKeyboardKey key) => KeyDownEvent(
  physicalKey: PhysicalKeyboardKey.arrowRight,
  logicalKey: key,
  timeStamp: Duration.zero,
);

KeyEvent _repeat(LogicalKeyboardKey key) => KeyRepeatEvent(
  physicalKey: PhysicalKeyboardKey.arrowRight,
  logicalKey: key,
  timeStamp: Duration.zero,
);

KeyEvent _up(LogicalKeyboardKey key) => KeyUpEvent(
  physicalKey: PhysicalKeyboardKey.arrowRight,
  logicalKey: key,
  timeStamp: Duration.zero,
);

void main() {
  tearDown(ShellTvHoldAccel.clearForTest);

  group('ShellTvHoldAccel.note', () {
    final t0 = DateTime(2026, 1, 1, 12);

    void holdFor(LogicalKeyboardKey key, int ms) {
      ShellTvHoldAccel.now = () => t0;
      ShellTvHoldAccel.note(_down(key));
      ShellTvHoldAccel.now = () => t0.add(Duration(milliseconds: ms));
      ShellTvHoldAccel.note(_repeat(key));
    }

    test('held → accelerates on the shared curve', () {
      holdFor(LogicalKeyboardKey.arrowRight, 2300);
      expect(ShellTvHoldAccel.lastStep, 3);
      expect(ShellTvHoldAccel.isHolding, isTrue);
    });

    test('held ← accelerates on the shared curve', () {
      holdFor(LogicalKeyboardKey.arrowLeft, 3600);
      expect(ShellTvHoldAccel.lastStep, 5);
    });

    test('held ↓ keeps the vertical curve (issue 156)', () {
      holdFor(LogicalKeyboardKey.arrowDown, 1300);
      expect(ShellTvHoldAccel.lastStep, 2);
      holdFor(LogicalKeyboardKey.arrowUp, 5200);
      expect(ShellTvHoldAccel.lastStep, 8);
    });

    test('short → hold stays 1-step', () {
      holdFor(LogicalKeyboardKey.arrowRight, 900);
      expect(ShellTvHoldAccel.lastStep, 1);
      expect(ShellTvHoldAccel.isHolding, isTrue);
    });

    test('discrete press is not a hold; key-up resets', () {
      ShellTvHoldAccel.now = () => t0;
      ShellTvHoldAccel.note(_down(LogicalKeyboardKey.arrowRight));
      expect(ShellTvHoldAccel.isHolding, isFalse);
      expect(ShellTvHoldAccel.lastStep, 1);

      holdFor(LogicalKeyboardKey.arrowRight, 2300);
      ShellTvHoldAccel.note(_up(LogicalKeyboardKey.arrowRight));
      expect(ShellTvHoldAccel.lastStep, 1);
      expect(ShellTvHoldAccel.isHolding, isFalse);
    });

    test('non-arrow key resets a horizontal hold', () {
      holdFor(LogicalKeyboardKey.arrowRight, 2300);
      ShellTvHoldAccel.note(_down(LogicalKeyboardKey.select));
      expect(ShellTvHoldAccel.lastStep, 1);
      expect(ShellTvHoldAccel.isHolding, isFalse);
    });

    test('switching arrow key restarts the hold clock', () {
      holdFor(LogicalKeyboardKey.arrowRight, 2300);
      ShellTvHoldAccel.now = () => t0.add(const Duration(milliseconds: 2400));
      ShellTvHoldAccel.note(_down(LogicalKeyboardKey.arrowLeft));
      expect(ShellTvHoldAccel.lastStep, 1);
      ShellTvHoldAccel.now = () => t0.add(const Duration(milliseconds: 2500));
      ShellTvHoldAccel.note(_repeat(LogicalKeyboardKey.arrowLeft));
      expect(ShellTvHoldAccel.lastStep, 1);
    });
  });

  group('ShellTvHoldAccel.stepForHoldMs', () {
    test('ramps stride with hold duration', () {
      expect(ShellTvHoldAccel.stepForHoldMs(0), 1);
      expect(ShellTvHoldAccel.stepForHoldMs(1199), 1);
      expect(ShellTvHoldAccel.stepForHoldMs(1200), 2);
      expect(ShellTvHoldAccel.stepForHoldMs(2199), 2);
      expect(ShellTvHoldAccel.stepForHoldMs(2200), 3);
      expect(ShellTvHoldAccel.stepForHoldMs(3499), 3);
      expect(ShellTvHoldAccel.stepForHoldMs(3500), 5);
      expect(ShellTvHoldAccel.stepForHoldMs(4999), 5);
      expect(ShellTvHoldAccel.stepForHoldMs(5000), 8);
      expect(ShellTvHoldAccel.stepForHoldMs(10_000), 8);
    });
  });

  group('ShellTvHoldAccel.seekStepForHoldMs', () {
    test('ramps at 3s / 7s / 11s', () {
      expect(ShellTvHoldAccel.seekStepForHoldMs(0), 1);
      expect(ShellTvHoldAccel.seekStepForHoldMs(2999), 1);
      expect(ShellTvHoldAccel.seekStepForHoldMs(3000), 2);
      expect(ShellTvHoldAccel.seekStepForHoldMs(6999), 2);
      expect(ShellTvHoldAccel.seekStepForHoldMs(7000), 3);
      expect(ShellTvHoldAccel.seekStepForHoldMs(10999), 3);
      expect(ShellTvHoldAccel.seekStepForHoldMs(11000), 5);
      expect(ShellTvHoldAccel.seekStepForHoldMs(20_000), 5);
    });
  });
}
