import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';

/// System bars for the shell (not the player).
///
/// Touch (mobile profile): edge-to-edge — status bar and gesture / button
/// nav stay visible with transparent backgrounds. The shell pads chrome with
/// [MediaQuery.paddingOf]. TV keeps sticky immersive. Players own the bars
/// while they are up (immersive) and the shell restores them after.
abstract final class ShellSystemUi {
  /// Re-apply after a player exit settles. Player teardown can still send
  /// sticky immersive from an async exit path after the surface flag drops.
  static const Duration playerExitSettle = Duration(milliseconds: 450);

  static const SystemUiOverlayStyle mobileOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
  );

  /// Mode the shell wants for [profile]. Null → leave the platform alone.
  @visibleForTesting
  static SystemUiMode? shellModeFor(ShellProfile profile, {bool? android}) {
    final isAndroid = android ?? (!kIsWeb && Platform.isAndroid);
    if (!isAndroid) return null;
    return switch (profile) {
      ShellProfile.mobile => SystemUiMode.edgeToEdge,
      ShellProfile.tv => SystemUiMode.immersiveSticky,
      ShellProfile.desktop => SystemUiMode.immersiveSticky,
    };
  }

  /// Apply the shell's system bars. No-op off Android.
  static Future<void> applyForShell(ShellProfile profile) async {
    final mode = shellModeFor(profile);
    if (mode == null) return;
    await SystemChrome.setEnabledSystemUIMode(mode);
    if (mode == SystemUiMode.edgeToEdge) {
      SystemChrome.setSystemUIOverlayStyle(mobileOverlayStyle);
    }
  }

  /// After a player surface closes: apply now and once more after
  /// [playerExitSettle].
  static void restoreAfterPlayer(
    ShellProfile Function() profile, {
    required bool Function() stillIdle,
  }) {
    unawaited(applyForShell(profile()));
    Timer(playerExitSettle, () {
      if (!stillIdle()) return;
      unawaited(applyForShell(profile()));
    });
  }
}
