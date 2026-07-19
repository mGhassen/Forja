import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/services/app_updater_release_notes.dart';
import 'package:forja/shared/services/release_storage_urls.dart';
import 'package:forja/shared/sync/src/desktop_browser_auth.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// In-app updates.
///
/// Discovery + download: Cloudflare R2 (`latest/manifest.json`, `v{ver}/{file}`).
/// Changelog bodies: GitHub Releases (not stored on R2).
class AppUpdaterService {
  static const String githubRepo = 'mGhassen/Forja';
  static const String githubReleasesUrl =
      'https://api.github.com/repos/$githubRepo/releases?per_page=100';

  static const Map<String, String> _jsonHeaders = {
    'Accept': 'application/json',
    'User-Agent': 'Forja-AppUpdater',
  };

  static const Map<String, String> _githubHeaders = {
    'Accept': 'application/vnd.github+json',
    'User-Agent': 'Forja-AppUpdater',
  };

  /// Portal changelog page (FORJA_WEB_URL /changelog).
  static String fullChangelogUrl() {
    final base = DesktopBrowserAuth.webUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base/changelog';
  }

  Future<UpdateInfo?> checkForUpdates() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      return _checkR2(currentVersion);
    } catch (e) {
      debugPrint('Error checking for updates: $e');
      return null;
    }
  }

  Future<UpdateInfo?> _checkR2(String currentVersion) async {
    // iOS updates go through the App Store — no sideload installer.
    if (Platform.isIOS) return null;

    final manifestUrl = ReleaseStorageUrls.manifestUrl();
    if (manifestUrl == null) {
      debugPrint('AppUpdater: RELEASE_CDN_URL is not set');
      return null;
    }

    final response = await http.get(
      Uri.parse(manifestUrl),
      headers: _jsonHeaders,
    );
    if (response.statusCode != 200) {
      debugPrint('AppUpdater: manifest HTTP ${response.statusCode}');
      return null;
    }

    final decoded = json.decode(response.body);
    if (decoded is! Map<String, dynamic>) return null;

    final version = (decoded['version'] as String?)?.trim();
    if (version == null || version.isEmpty) return null;

    if (!AppUpdaterReleaseNotes.isNewerVersion(currentVersion, version)) {
      return null;
    }

    final assetsRaw = decoded['assets'];
    if (assetsRaw is! List) return null;
    final assets = <String>[
      for (final a in assetsRaw)
        if (a is String && a.isNotEmpty) a,
    ];
    if (assets.isEmpty) return null;

    final downloadUrl = _pickInstallerUrl(version, assets);
    if (downloadUrl == null || downloadUrl.isEmpty) return null;

    final publishedRaw = decoded['published_at'] as String?;
    final publishedAt = publishedRaw != null
        ? DateTime.tryParse(publishedRaw) ?? DateTime.now()
        : DateTime.now();

    final changelogs = await _fetchChangelogs(
      currentVersion: currentVersion,
      latestVersion: version,
    );

    return UpdateInfo(
      currentVersion: currentVersion,
      latestVersion: version,
      downloadUrl: downloadUrl,
      changelogs: changelogs,
      fullChangelogUrl: fullChangelogUrl(),
      publishedAt: publishedAt,
      isMacOS: Platform.isMacOS,
      isIOS: false,
    );
  }

  /// Changelog text from GitHub Releases (max 16 versions since installed).
  Future<List<VersionChangelog>> _fetchChangelogs({
    required String currentVersion,
    required String latestVersion,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(githubReleasesUrl),
        headers: _githubHeaders,
      );
      if (response.statusCode != 200) return const [];

      final decoded = json.decode(response.body);
      if (decoded is! List) return const [];

      final entries = <ReleaseNotesEntry>[];
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        final tag = item['tag_name'] as String?;
        if (tag == null || tag.isEmpty) continue;
        entries.add(
          ReleaseNotesEntry(
            version: tag.replaceFirst(RegExp(r'^v'), ''),
            body: item['body'] as String?,
            prerelease: item['prerelease'] as bool? ?? false,
            draft: item['draft'] as bool? ?? false,
          ),
        );
      }

      return AppUpdaterReleaseNotes.collect(
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        releases: entries,
      );
    } catch (e) {
      debugPrint('AppUpdater: changelog fetch failed: $e');
      return const [];
    }
  }

  String? _pickInstallerUrl(String version, List<String> assets) {
    final String? filename;
    if (Platform.isWindows) {
      filename = _firstMatching(
        assets,
        (n) => n.contains('windows') && n.endsWith('.exe'),
      );
    } else if (Platform.isLinux) {
      filename = _firstMatching(
        assets,
        (n) =>
            n.contains('linux') &&
            (n.endsWith('.appimage') || n.endsWith('.deb')),
      );
    } else if (Platform.isMacOS) {
      filename = _pickMacosFilename(assets);
    } else if (Platform.isAndroid) {
      filename = _pickAndroidFilename(assets);
    } else {
      filename = null;
    }
    if (filename == null || filename.isEmpty) return null;
    final url = ReleaseStorageUrls.preferStorage(
      version: version,
      filename: filename,
    );
    return url.isEmpty ? null : url;
  }

  String? _firstMatching(List<String> assets, bool Function(String lower) test) {
    for (final name in assets) {
      if (test(name.toLowerCase())) return name;
    }
    return null;
  }

  String? _pickMacosFilename(List<String> assets) {
    final macos = assets
        .where((n) {
          final lower = n.toLowerCase();
          return lower.contains('macos') &&
              (lower.endsWith('.dmg') || lower.endsWith('.zip'));
        })
        .toList();
    if (macos.isEmpty) return null;

    final arch = _macosArchNeedle();
    for (final name in macos) {
      final lower = name.toLowerCase();
      if (lower.contains(arch) && lower.endsWith('.dmg')) return name;
    }
    for (final name in macos) {
      if (name.toLowerCase().endsWith('.dmg')) return name;
    }
    return macos.first;
  }

  String? _pickAndroidFilename(List<String> assets) {
    final apks =
        assets.where((n) => n.toLowerCase().endsWith('.apk')).toList();
    if (apks.isEmpty) return null;

    final tv = apks
        .where((n) => n.toLowerCase().contains('android-tv'))
        .toList();
    final candidates = tv.isNotEmpty ? tv : apks;

    final is64Bit = sizeOf<IntPtr>() == 8;
    final abiNeedle = is64Bit ? 'arm64' : 'armeabi-v7a';
    final abiFallback = is64Bit ? 'v7a' : 'arm64';

    for (final needle in [abiNeedle, abiFallback]) {
      for (final name in candidates) {
        if (name.toLowerCase().contains(needle)) return name;
      }
    }
    return candidates.first;
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

class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String downloadUrl;
  final List<VersionChangelog> changelogs;
  final String fullChangelogUrl;
  final DateTime publishedAt;
  final bool isMacOS;
  final bool isIOS;

  UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.changelogs,
    required this.fullChangelogUrl,
    required this.publishedAt,
    required this.isMacOS,
    this.isIOS = false,
  });
}
