import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:forja/shared/platform/platform_info.dart';

/// Patches WebView settings for Android TV.
///
/// ATV emulators (and some devices) expose no GLES version to Chromium's GPU
/// process, which aborts with `gl_version_info.cc: Chrome runs only on top of
/// OpenGL ES`. Software compositing avoids that fatal init.
///
/// Mutates [settings] in place. Do **not** use [InAppWebViewSettings.copy] —
/// it round-trips via `fromMap(toMap())`, and on Android
/// `ContentBlockerAction.fromMap` bangs when any `contentBlockers` are set
/// (plugin initializes `BLOCK_COOKIES` with a null native value). That crashed
/// Live Matches embeds on ATV with a red screen.
InAppWebViewSettings patchTvWebViewSettings(
  InAppWebViewSettings settings, {
  required bool isAndroidTv,
}) {
  if (!isAndroidTv) return settings;
  settings.hardwareAcceleration = false;
  return settings;
}

/// Windows WebView2 create-time bug in `flutter_inappwebview_windows` 0.6.x:
/// `transparentBackground: false` calls `put_DefaultBackgroundColor` with
/// alpha `0` (see `in_app_webview.cpp` ~210), so the platform view is
/// see-through white. Flutter still receives Escape / route pop.
///
/// Forcing `true` skips that branch; WebView2 keeps an opaque default and
/// page CSS paints the dark player background.
/// Upstream: https://github.com/pichillilorenzo/flutter_inappwebview/issues/2735
///
/// Mutates in place — same [InAppWebViewSettings.copy] hazard as the TV patch
/// when [InAppWebViewSettings.contentBlockers] is non-empty.
InAppWebViewSettings patchWindowsWebViewSettings(InAppWebViewSettings settings) {
  if (kIsWeb || !Platform.isWindows) return settings;
  settings.transparentBackground = true;
  return settings;
}

InAppWebViewSettings forjaWebViewSettings(InAppWebViewSettings settings) {
  final tvPatched = patchTvWebViewSettings(
    settings,
    isAndroidTv: PlatformInfo.isAndroidTv,
  );
  return patchWindowsWebViewSettings(tvPatched);
}
