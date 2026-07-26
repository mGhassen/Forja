import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:forja/shared/platform/platform_info.dart';

/// Patches WebView settings for Android TV.
///
/// Historically forced `hardwareAcceleration: false` (View `LAYER_TYPE_NONE`)
/// to dodge Chromium GLES aborts on ATV emulators. That does **not** stop
/// `Chrome_InProcGp` / `gl_version_info.cc`, and it blanks YouTube / HTML5
/// video on real devices (white trailer player and hero). Emulator GLES is
/// handled by `scripts/atv-run.sh` (`--disable-gpu`) and by blocking headless
/// extractors — keep View HA on.
///
/// Mutates [settings] in place when a future TV patch is needed. Do **not**
/// use [InAppWebViewSettings.copy] - it round-trips via `fromMap(toMap())`,
/// and on Android `ContentBlockerAction.fromMap` bangs when any
/// `contentBlockers` are set (plugin initializes `BLOCK_COOKIES` with a null
/// native value). That crashed Live Matches embeds on ATV with a red screen.
InAppWebViewSettings patchTvWebViewSettings(
  InAppWebViewSettings settings, {
  required bool isAndroidTv,
}) {
  if (!isAndroidTv) return settings;
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
/// Mutates in place - same [InAppWebViewSettings.copy] hazard as the TV patch
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
