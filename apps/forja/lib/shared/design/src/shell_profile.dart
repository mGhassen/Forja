import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';

enum ShellProfile { mobile, desktop, tv }

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
