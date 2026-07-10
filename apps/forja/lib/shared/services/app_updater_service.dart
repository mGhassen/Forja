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

      final response = await http.get(Uri.parse(githubApiUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion =
            (data['tag_name'] as String).replaceFirst('v', '');
        final releaseNotes =
            data['body'] as String? ?? 'No release notes available';
        final publishedAt = DateTime.parse(data['published_at']);

        if (_isNewerVersion(currentVersion, latestVersion)) {
          String? downloadUrl;
          final assets = data['assets'] as List;

          if (Platform.isWindows) {
            final asset = assets.firstWhere(
              (a) =>
                  (a['name'] as String).toLowerCase().contains('windows') &&
                  (a['name'] as String).endsWith('.exe'),
              orElse: () => null,
            );
            downloadUrl = asset?['browser_download_url'];
          } else if (Platform.isLinux) {
            final asset = assets.firstWhere(
              (a) =>
                  (a['name'] as String).toLowerCase().contains('linux') &&
                  ((a['name'] as String).endsWith('.AppImage') ||
                      (a['name'] as String).endsWith('.deb')),
              orElse: () => null,
            );
            downloadUrl = asset?['browser_download_url'];
          } else if (Platform.isMacOS) {
            downloadUrl = data['html_url'];
          } else if (Platform.isAndroid) {
            downloadUrl = _pickAndroidApkUrl(assets);
          } else if (Platform.isIOS) {
            downloadUrl = data['html_url'];
          }

          return UpdateInfo(
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            downloadUrl: downloadUrl ?? data['html_url'],
            releaseNotes: releaseNotes,
            publishedAt: publishedAt,
            isMacOS: Platform.isMacOS,
            isIOS: Platform.isIOS,
          );
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error checking for updates: $e');
      return null;
    }
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
