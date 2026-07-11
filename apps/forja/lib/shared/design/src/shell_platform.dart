import 'package:forja/shared/design/src/shell_input_policy.dart';
import 'package:forja/shared/design/src/shell_metrics.dart';
import 'package:forja/shared/design/src/shell_profile.dart';

enum ShellChromeKind { bottomNav, navRail, navRailTv }

class ShellPlatformConfig {
  const ShellPlatformConfig({
    required this.metrics,
    required this.inputPolicy,
    required this.chromeKind,
  });

  final ShellMetrics metrics;
  final ShellInputPolicy inputPolicy;
  final ShellChromeKind chromeKind;

  bool get useNavRail =>
      chromeKind == ShellChromeKind.navRail ||
      chromeKind == ShellChromeKind.navRailTv;

  bool get showHomeTopBar => useNavRail;
}

const shellPlatformConfigs = <ShellProfile, ShellPlatformConfig>{
  ShellProfile.mobile: ShellPlatformConfig(
    metrics: ShellMetrics.mobile,
    inputPolicy: ShellInputPolicy.mobile,
    chromeKind: ShellChromeKind.bottomNav,
  ),
  ShellProfile.desktop: ShellPlatformConfig(
    metrics: ShellMetrics.desktop,
    inputPolicy: ShellInputPolicy.desktop,
    chromeKind: ShellChromeKind.navRail,
  ),
  ShellProfile.tv: ShellPlatformConfig(
    metrics: ShellMetrics.tv,
    inputPolicy: ShellInputPolicy.tv,
    chromeKind: ShellChromeKind.navRailTv,
  ),
};

ShellPlatformConfig shellPlatformConfigFor(ShellProfile profile) =>
    shellPlatformConfigs[profile]!;
