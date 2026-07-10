import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:forja/shared/platform/platform_info.dart';

/// Patches WebView settings for Android TV.
///
/// ATV emulators (and some devices) expose no GLES version to Chromium's GPU
/// process, which aborts with `gl_version_info.cc: Chrome runs only on top of
/// OpenGL ES`. Software compositing avoids that fatal init.
InAppWebViewSettings forjaWebViewSettings(InAppWebViewSettings settings) {
  if (!PlatformInfo.isAndroidTv) return settings;
  final patched = settings.copy();
  patched.hardwareAcceleration = false;
  return patched;
}
