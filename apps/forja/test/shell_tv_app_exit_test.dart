import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/tv/shell_tv_app_exit.dart';

void main() {
  tearDown(ShellTvAppExit.resetForTest);

  test('arm then instant confirm stays armed (same-press duplicate)', () {
    var exited = 0;
    ShellTvAppExit.debugExitOverride = () async {
      exited++;
    };
    var now = DateTime(2026, 1, 1, 12);
    ShellTvAppExit.debugNow = () => now;

    expect(
      ShellTvAppExit.armOrExit(message: 'Press Back again to exit'),
      ShellTvAppExitOutcome.armed,
    );
    expect(
      ShellTvAppExit.armOrExit(message: 'Press Back again to exit'),
      ShellTvAppExitOutcome.armed,
    );
    expect(exited, 0);
    expect(ShellTvAppExit.isArmed, isTrue);
  });

  test('arm then confirm after minConfirmGap exits', () async {
    var exited = 0;
    ShellTvAppExit.debugExitOverride = () async {
      exited++;
    };
    var now = DateTime(2026, 1, 1, 12);
    ShellTvAppExit.debugNow = () => now;

    expect(
      ShellTvAppExit.armOrExit(message: 'Press Back again to exit'),
      ShellTvAppExitOutcome.armed,
    );

    now = now.add(ShellTvAppExit.minConfirmGap + const Duration(milliseconds: 10));
    expect(
      ShellTvAppExit.armOrExit(message: 'Press Back again to exit'),
      ShellTvAppExitOutcome.exited,
    );
    expect(exited, 1);
    expect(ShellTvAppExit.isArmed, isFalse);
  });
}
