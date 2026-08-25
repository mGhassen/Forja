import 'dart:ffi';
import 'dart:io';

import 'package:forja/shared/platform/platform_info.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Allowlisted PostHog person properties for the current install (RFC-043).
abstract final class ClientRuntimeProps {
  static Future<Map<String, Object>> collect() async {
    final info = await PackageInfo.fromPlatform();
    return {
      'app_version': info.version,
      'platform': _platform(),
      'os_version': Platform.operatingSystemVersion,
      'arch': _arch(),
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  static String _platform() {
    if (PlatformInfo.isAndroidTv) return 'android_tv';
    return Platform.operatingSystem;
  }

  /// Matches R2 / updater arch keys where possible.
  static String _arch() {
    if (Platform.isMacOS || Platform.isLinux) {
      try {
        final result = Process.runSync('uname', ['-m']);
        final machine = (result.stdout as String).trim().toLowerCase();
        if (machine == 'x86_64' || machine == 'amd64' || machine == 'i386') {
          return 'x86_64';
        }
        if (machine == 'arm64' || machine == 'aarch64') return 'arm64';
        if (machine.isNotEmpty) return machine;
      } catch (_) {}
      return Platform.isMacOS ? 'arm64' : 'unknown';
    }
    if (Platform.isAndroid) {
      return sizeOf<IntPtr>() == 8 ? 'arm64' : 'armeabi-v7a';
    }
    if (Platform.isWindows) return 'x86_64';
    if (Platform.isIOS) return 'arm64';
    return 'unknown';
  }
}
