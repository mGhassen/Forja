import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';

enum ShellProfile { mobile, desktop, tv }

/// Maps boot-time TV detection + layout to [ShellProfile].
///
/// Feature code must use [ShellScope.profileOf] / [ShellScope.metricsOf] /
/// [ShellScope.inputPolicyOf], or [PlatformInfo] when [BuildContext] is
/// unavailable — never [ShellTokens.isTvLayout] outside this resolver.
ShellProfile resolveShellProfile(BuildContext context) {
  if (ShellTokens.isTvLayout(context)) return ShellProfile.tv;
  if (!kIsWeb &&
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    return ShellProfile.desktop;
  }
  if (MediaQuery.sizeOf(context).width > ShellTokens.musicDesktopBreakpoint) {
    return ShellProfile.desktop;
  }
  return ShellProfile.mobile;
}
