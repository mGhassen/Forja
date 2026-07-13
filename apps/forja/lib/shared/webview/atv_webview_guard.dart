import 'package:forja/shared/platform/platform_info.dart';
import 'package:rust/rust.dart';

/// Headless WebView loads Chromium's GPU process; ATV emulators often have no
/// GLES and abort in `gl_version_info.cc`. Block sniff/extract paths on TV
/// unless [SettingsService.allowAndroidTvHeadlessWebViewExtractors] is true.
bool get isAndroidTvHeadlessWebViewBlocked =>
    PlatformInfo.isAndroidTv &&
    !SettingsService.allowAndroidTvHeadlessWebViewExtractors;
