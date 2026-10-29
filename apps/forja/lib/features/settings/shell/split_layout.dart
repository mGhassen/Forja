import 'package:flutter/widgets.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja_foundation/tokens/forja_settings_tokens.dart';
import 'package:forja_foundation/tokens/mobile_chrome_tokens.dart';

/// True when the Settings hub shows the split sidebar + detail pane.
///
/// TV / desktop: [SettingsTokens.useSplitLayout] (width). Phone profile stays
/// single-pane (list → push) in both orientations; a tablet-sized mobile
/// screen keeps the split.
bool settingsUseSplitLayout(BuildContext context) {
  if (!SettingsTokens.useSplitLayout(context)) return false;
  if (ShellScope.maybeOf(context)?.profile != ShellProfile.mobile) return true;
  return MediaQuery.sizeOf(context).shortestSide >=
      MobileChromeTokens.settingsSplitMinShortestSide;
}

/// Phone single-pane list shows the credits / version footer at the end.
bool settingsCompactListShowsFooter(BuildContext context) =>
    ShellScope.maybeOf(context)?.profile == ShellProfile.mobile;
