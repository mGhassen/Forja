import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/services/app_updater_release_notes.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdaterService {
  static const String githubRepo = 'mGhassen/Forja';
  static const String githubReleasesUrl =
      'https://api.github.com/repos/$githubRepo/releases?per_page=100';

  static const Map<String, String> _githubHeaders = {
    'Accept': 'application/vnd.github+json',
    'User-Agent': 'Forja-AppUpdater',
  };

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
    final response = await http.get(
      Uri.parse(githubReleasesUrl),
      headers: _githubHeaders,
    );

    if (response.statusCode != 200) return null;

    final decoded = json.decode(response.body);
    if (decoded is! List) return null;

    final releases = <_GitHubRelease>[];
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) continue;
      final parsed = _GitHubRelease.tryParse(item);
      if (parsed != null) releases.add(parsed);
    }

    final stable = releases
        .where((r) => !r.draft && !r.prerelease)
        .toList()
      ..sort(
        (a, b) => AppUpdaterReleaseNotes.compareVersions(b.version, a.version),
      );

    if (stable.isEmpty) return null;

    final latest = stable.first;
    if (!AppUpdaterReleaseNotes.isNewerVersion(
      currentVersion,
      latest.version,
    )) {
      return null;
    }

    final releaseNotes = AppUpdaterReleaseNotes.aggregate(
      currentVersion: currentVersion,
      releases: [
        for (final r in stable)
          ReleaseNotesEntry(
            version: r.version,
            body: r.body,
            prerelease: r.prerelease,
            draft: r.draft,
          ),
      ],
    );

    final notes = releaseNotes.isEmpty
        ? 'No release notes were published for this update.'
        : releaseNotes;

    String? downloadUrl;
    final assets = latest.assets;

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
      downloadUrl = latest.htmlUrl;
    }

    return UpdateInfo(
      currentVersion: currentVersion,
      latestVersion: latest.version,
      downloadUrl: downloadUrl ?? latest.htmlUrl,
      releaseNotes: notes,
      publishedAt: latest.publishedAt,
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

  Future<void> openDownloadPage(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _GitHubRelease {
  const _GitHubRelease({
    required this.version,
    required this.body,
    required this.publishedAt,
    required this.prerelease,
    required this.draft,
    required this.assets,
    required this.htmlUrl,
  });

  final String version;
  final String? body;
  final DateTime publishedAt;
  final bool prerelease;
  final bool draft;
  final List<dynamic> assets;
  final String htmlUrl;

  static _GitHubRelease? tryParse(Map<String, dynamic> data) {
    final tag = data['tag_name'] as String?;
    if (tag == null || tag.isEmpty) return null;
    final publishedRaw = data['published_at'] as String?;
    if (publishedRaw == null) return null;

    return _GitHubRelease(
      version: tag.replaceFirst(RegExp(r'^v'), ''),
      body: data['body'] as String?,
      publishedAt: DateTime.parse(publishedRaw),
      prerelease: data['prerelease'] as bool? ?? false,
      draft: data['draft'] as bool? ?? false,
      assets: data['assets'] as List? ?? const [],
      htmlUrl: data['html_url'] as String? ??
          'https://github.com/${AppUpdaterService.githubRepo}/releases',
    );
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
