import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

enum ShellProfile { mobile, desktop, tv }

/// Host OS family for [resolveShellProfileFor].
enum ShellHostOs { android, desktop, other }

/// Maps boot-time TV detection + layout to [ShellProfile].
///
/// Feature code must use [ShellScope.profileOf] / [ShellScope.metricsOf] /
/// [ShellScope.inputPolicyOf], or [PlatformInfo] when [BuildContext] is
/// unavailable - never [ShellTokens.isTvLayout] outside this resolver.
ShellProfile resolveShellProfile(BuildContext context) {
  final os = kIsWeb
      ? ShellHostOs.other
      : Platform.isAndroid
      ? ShellHostOs.android
      : (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
      ? ShellHostOs.desktop
      : ShellHostOs.other;
  return resolveShellProfileFor(
    os: os,
    logicalSize: MediaQuery.sizeOf(context),
    androidMobileFormFactor: ShellTokens.androidMobileFormFactor,
    // Native leanback, physical-panel fallback, and logical TV size — all
    // already false in the mobile flavor.
    androidTvDevice: os == ShellHostOs.android && ShellTokens.isTvLayout(context),
  );
}

/// Pure profile rule behind [resolveShellProfile].
///
/// Android mobile builds always resolve [ShellProfile.mobile] — phones in
/// either orientation and tablets. Android TV builds keep native detection,
/// the physical 16:9 panel fallback, and the logical-size TV layout.
ShellProfile resolveShellProfileFor({
  required ShellHostOs os,
  required Size logicalSize,
  bool androidMobileFormFactor = false,
  bool androidTvDevice = false,
  Size? physicalSize,
}) {
  if (os == ShellHostOs.android) {
    if (androidMobileFormFactor) return ShellProfile.mobile;
    if (androidTvDevice) return ShellProfile.tv;
    if (physicalSize != null &&
        ShellTokens.looksLikeAndroidTvPanel(physicalSize)) {
      return ShellProfile.tv;
    }
    if (ShellTokens.isTvLayoutSize(logicalSize)) return ShellProfile.tv;
  }
  if (os == ShellHostOs.desktop) return ShellProfile.desktop;
  if (logicalSize.width > ShellTokens.musicDesktopBreakpoint) {
    return ShellProfile.desktop;
  }
  return ShellProfile.mobile;
}
