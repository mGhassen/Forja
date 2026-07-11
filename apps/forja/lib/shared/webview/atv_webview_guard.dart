import 'package:forja/shared/platform/platform_info.dart';

/// Headless WebView loads Chromium's GPU process; ATV emulators often have no
/// GLES and abort in `gl_version_info.cc`. Block sniff/extract paths on TV.
bool get isAndroidTvHeadlessWebViewBlocked => PlatformInfo.isAndroidTv;
