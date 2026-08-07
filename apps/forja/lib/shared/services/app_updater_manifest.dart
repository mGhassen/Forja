/// Pure helpers to resolve the update target from R2 `latest/manifest.json`.
///
/// Supports per-platform latest (partial releases keep other platforms) and the
/// legacy flat `{ version, assets }` shape.
import 'package:forja/shared/services/app_updater_release_notes.dart';

class PlatformUpdateTarget {
  const PlatformUpdateTarget({
    required this.version,
    required this.assets,
    this.publishedAt,
  });

  final String version;
  final List<String> assets;
  final DateTime? publishedAt;
}

class AppUpdaterManifest {
  AppUpdaterManifest._();

  static final _versionInName = RegExp(
    r'forja-(\d+\.\d+\.\d+)',
    caseSensitive: false,
  );

  /// Semver embedded in installer filenames (`Forja-1.3.192-macos-arm64.dmg`).
  static String? versionFromFilename(String name) {
    return _versionInName.firstMatch(name)?.group(1);
  }

  /// Showcase keys matching web / R2 upload (`windows` · `macos` · `linux` · `android_tv`).
  static String? platformKey({
    required bool isWindows,
    required bool isMacOS,
    required bool isLinux,
    required bool isAndroid,
  }) {
    if (isWindows) return 'windows';
    if (isMacOS) return 'macos';
    if (isLinux) return 'linux';
    if (isAndroid) return 'android_tv';
    return null;
  }

  /// Prefer `platforms.{key}`; fall back to legacy flat `version` + `assets`.
  static PlatformUpdateTarget? resolve({
    required Map<String, dynamic> manifest,
    required String platformKey,
  }) {
    final platforms = manifest['platforms'];
    if (platforms is Map) {
      final raw = platforms[platformKey];
      if (raw is Map) {
        final version = (raw['version'] as String?)?.trim().replaceFirst(
          RegExp(r'^v'),
          '',
        );
        final assetsRaw = raw['assets'];
        final assets = <String>[
          if (assetsRaw is List)
            for (final a in assetsRaw)
              if (a is String && a.isNotEmpty) a,
        ];
        if (version != null && version.isNotEmpty && assets.isNotEmpty) {
          final publishedRaw = raw['published_at'] as String?;
          return PlatformUpdateTarget(
            version: version,
            assets: assets,
            publishedAt: publishedRaw != null
                ? DateTime.tryParse(publishedRaw)
                : null,
          );
        }
      }
    }

    final version = (manifest['version'] as String?)?.trim().replaceFirst(
      RegExp(r'^v'),
      '',
    );
    final assetsRaw = manifest['assets'];
    if (version == null || version.isEmpty || assetsRaw is! List) {
      return null;
    }
    final assets = <String>[
      for (final a in assetsRaw)
        if (a is String && a.isNotEmpty) a,
    ];
    if (assets.isEmpty) return null;

    final publishedRaw = manifest['published_at'] as String?;
    return PlatformUpdateTarget(
      version: version,
      assets: assets,
      publishedAt: publishedRaw != null ? DateTime.tryParse(publishedRaw) : null,
    );
  }

  /// True when [latest] is newer than [current] for this platform target.
  static bool isUpdateAvailable({
    required String currentVersion,
    required PlatformUpdateTarget target,
  }) {
    return AppUpdaterReleaseNotes.isNewerVersion(
      currentVersion,
      target.version,
    );
  }
}
