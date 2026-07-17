import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdaterService {
  static const String githubRepo = 'mGhassen/Forja';
  static const String githubApiUrl =
      'https://api.github.com/repos/$githubRepo/releases/latest';

  Future<UpdateInfo?> checkForUpdates() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      return _checkGitHub(currentVersion);
    } catch (e) {
      debugPrint('Error checking for updates: $e');
      return null;
    }
  }

  Future<UpdateInfo?> _checkGitHub(String currentVersion) async {
    final response = await http.get(Uri.parse(githubApiUrl));

    if (response.statusCode != 200) return null;

    final data = json.decode(response.body) as Map<String, dynamic>;
    final latestVersion =
        (data['tag_name'] as String).replaceFirst('v', '');
    final releaseNotes =
        data['body'] as String? ?? 'No release notes available';
    final publishedAt = DateTime.parse(data['published_at'] as String);

    if (!_isNewerVersion(currentVersion, latestVersion)) return null;

    String? downloadUrl;
    final assets = data['assets'] as List;

    if (Platform.isWindows) {
      final asset = assets.cast<dynamic>().firstWhere(
            (a) =>
                (a['name'] as String).toLowerCase().contains('windows') &&
                (a['name'] as String).endsWith('.exe'),
            orElse: () => null,
          );
      downloadUrl = asset?['browser_download_url'] as String?;
    } else if (Platform.isLinux) {
      final asset = assets.cast<dynamic>().firstWhere(
            (a) =>
                (a['name'] as String).toLowerCase().contains('linux') &&
                ((a['name'] as String).endsWith('.AppImage') ||
                    (a['name'] as String).endsWith('.deb')),
            orElse: () => null,
          );
      downloadUrl = asset?['browser_download_url'] as String?;
    } else if (Platform.isMacOS) {
      downloadUrl = _pickMacosDmgUrl(assets);
    } else if (Platform.isAndroid) {
      downloadUrl = _pickAndroidApkUrl(assets);
    } else if (Platform.isIOS) {
      downloadUrl = data['html_url'] as String?;
    }

    return UpdateInfo(
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      downloadUrl: downloadUrl ?? data['html_url'] as String,
      releaseNotes: releaseNotes,
      publishedAt: publishedAt,
      isMacOS: Platform.isMacOS,
      isIOS: Platform.isIOS,
    );
  }

  String? _pickAndroidApkUrl(List<dynamic> assets) {
    final apks = assets
        .where((a) => (a['name'] as String).toLowerCase().endsWith('.apk'))
        .toList();
    if (apks.isEmpty) return null;

    final tvApks = apks
        .where((a) => (a['name'] as String).toLowerCase().contains('android-tv'))
        .toList();
    final candidates = tvApks.isNotEmpty ? tvApks : apks;

    final is64Bit = sizeOf<IntPtr>() == 8;
    final abiNeedle = is64Bit ? 'arm64' : 'armeabi-v7a';
    final abiFallback = is64Bit ? 'v7a' : 'arm64';

    for (final needle in [abiNeedle, abiFallback]) {
      for (final asset in candidates) {
        final name = (asset['name'] as String).toLowerCase();
        if (name.contains(needle)) {
          return asset['browser_download_url'] as String;
        }
      }
    }

    return candidates.first['browser_download_url'] as String?;
  }

  /// Prefer `Forja-*-macos-arm64.dmg` (CI), then any macOS `.dmg` / `.zip`.
  String? _pickMacosDmgUrl(List<dynamic> assets) {
    final macosAssets = assets.where((a) {
      final name = (a['name'] as String).toLowerCase();
      return name.contains('macos') &&
          (name.endsWith('.dmg') || name.endsWith('.zip'));
    }).toList();
    if (macosAssets.isEmpty) return null;

    final archNeedle = _macosArchNeedle();
    for (final asset in macosAssets) {
      final name = (asset['name'] as String).toLowerCase();
      if (name.contains(archNeedle) && name.endsWith('.dmg')) {
        return asset['browser_download_url'] as String;
      }
    }
    for (final asset in macosAssets) {
      final name = (asset['name'] as String).toLowerCase();
      if (name.endsWith('.dmg')) {
        return asset['browser_download_url'] as String;
      }
    }
    return macosAssets.first['browser_download_url'] as String?;
  }

  String _macosArchNeedle() {
    try {
      final result = Process.runSync('uname', ['-m']);
      final machine = (result.stdout as String).trim().toLowerCase();
      if (machine == 'x86_64' || machine == 'i386') return 'x86_64';
      if (machine == 'arm64' || machine == 'aarch64') return 'arm64';
    } catch (_) {}
    return 'arm64';
  }

  bool _isNewerVersion(String current, String latest) {
    final currentParts = current.split('.').map(int.parse).toList();
    final latestParts = latest.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
      final currentPart = i < currentParts.length ? currentParts[i] : 0;
      final latestPart = i < latestParts.length ? latestParts[i] : 0;

      if (latestPart > currentPart) return true;
      if (latestPart < currentPart) return false;
    }
    return false;
  }

  Future<void> openDownloadPage(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;
  final DateTime publishedAt;
  final bool isMacOS;
  final bool isIOS;

  UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.publishedAt,
    required this.isMacOS,
    this.isIOS = false,
  });
}
