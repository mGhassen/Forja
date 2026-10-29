import 'package:forja/shell/core/forja_shell_input_policy.dart';
import 'package:forja/shell/core/forja_shell_metrics.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';

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

  /// Pack hub top bar (search, hub menus). Every profile paints it so phones
  /// reach the same hub actions as TV and desktop.
  bool get showKitTopBar => true;
}

const shellPlatformConfigs = <ShellProfile, ShellPlatformConfig>{
  ShellProfile.mobile: ShellPlatformConfig(
    metrics: ShellMetrics.mobile,
    inputPolicy: ShellInputPolicy.mobile,
    chromeKind: ShellChromeKind.bottomNav,
  ),
  ShellProfile.desktop: ShellPlatformConfig(
    metrics: ShellMetrics.desktop,
    // Hover + Ken Burns + density/chrome; D-pad via ShellInputPolicy.desktop.
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
