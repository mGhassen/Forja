import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:forja/shared/platform/platform_info.dart';

/// Patches WebView settings for Android TV.
///
/// ATV emulators (and some devices) expose no GLES version to Chromium's GPU
/// process, which aborts with `gl_version_info.cc: Chrome runs only on top of
/// OpenGL ES`. Software compositing avoids that fatal init.
InAppWebViewSettings patchTvWebViewSettings(
  InAppWebViewSettings settings, {
  required bool isAndroidTv,
}) {
  if (!isAndroidTv) return settings;
  final patched = settings.copy();
  patched.hardwareAcceleration = false;
  return patched;
}

/// Windows WebView2 create-time bug in `flutter_inappwebview_windows` 0.6.x:
/// `transparentBackground: false` calls `put_DefaultBackgroundColor` with
/// alpha `0` (see `in_app_webview.cpp` ~210), so the platform view is
/// see-through white. Flutter still receives Escape / route pop.
///
/// Forcing `true` skips that branch; WebView2 keeps an opaque default and
/// page CSS paints the dark player background.
/// Upstream: https://github.com/pichillilorenzo/flutter_inappwebview/issues/2735
InAppWebViewSettings patchWindowsWebViewSettings(InAppWebViewSettings settings) {
  if (kIsWeb || !Platform.isWindows) return settings;
  final patched = settings.copy();
  patched.transparentBackground = true;
  return patched;
}

InAppWebViewSettings forjaWebViewSettings(InAppWebViewSettings settings) {
  final tvPatched = patchTvWebViewSettings(
    settings,
    isAndroidTv: PlatformInfo.isAndroidTv,
  );
  return patchWindowsWebViewSettings(tvPatched);
}
