import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/tv/shell_tv_hold_accel.dart';

void main() {
  tearDown(ShellTvHoldAccel.clearForTest);

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
}
