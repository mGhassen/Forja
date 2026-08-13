/// Pure helpers to resolve the update target from R2 `latest/manifest.json`.
///
/// Supports per-platform latest (partial releases keep other platforms),
/// per-arch `arches` maps, and the legacy flat `{ version, assets }` shape.
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

/// One CPU arch's installer from `platforms.*.arches`.
class ArchUpdateTarget {
  const ArchUpdateTarget({
    required this.arch,
    required this.version,
    required this.filename,
    this.publishedAt,
  });

  final String arch;
  final String version;
  final String filename;
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

  /// Architecture slot matching R2 upload (`arm64`, `x86_64`, `armeabi-v7a`, …).
  static String detectArchFromFilename(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('armeabi-v7a') || lower.contains('armeabi_v7a')) {
      return 'armeabi-v7a';
    }
    if (lower.contains('arm64') || lower.contains('aarch64')) return 'arm64';
    if (lower.contains('x86_64') ||
        lower.contains('x86-64') ||
        lower.contains('amd64')) {
      return 'x86_64';
    }
    if (RegExp(r'(?<![a-z0-9])x86(?![_a-z0-9])').hasMatch(lower)) {
      return 'x86';
    }
    return 'default';
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

  /// Resolve the installer for [arch] from `platforms.*.arches`, with fallbacks.
  ///
  /// Prefer explicit `arches.{arch}`; else pick matching asset filename;
  /// else single `default` / sole asset. Returns null when this arch has no
  /// installer (do not fall back to a different CPU's build).
  static ArchUpdateTarget? resolveForArch({
    required Map<String, dynamic> manifest,
    required String platformKey,
    required String arch,
  }) {
    final platform = _platformEntry(manifest, platformKey);
    if (platform == null) return null;

    final arches = platform['arches'];
    if (arches is Map) {
      final direct = _archEntryFromMap(arches, arch);
      if (direct != null) return direct;

      // Host arch unknown / unlisted — only accept sole `default` slot.
      if (arch != 'default') {
        final onlyDefault = _archEntryFromMap(arches, 'default');
        if (onlyDefault != null && arches.length == 1) return onlyDefault;
        return null;
      }
    }

    final assets = <String>[
      if (platform['assets'] is List)
        for (final a in platform['assets'] as List)
          if (a is String && a.isNotEmpty) a,
    ];
    if (assets.isEmpty) return null;

    for (final name in assets) {
      if (detectArchFromFilename(name) == arch) {
        final version =
            versionFromFilename(name) ??
            (platform['version'] as String?)?.trim().replaceFirst(
              RegExp(r'^v'),
              '',
            );
        if (version == null || version.isEmpty) continue;
        final publishedRaw =
            platform['published_at'] as String? ??
            manifest['published_at'] as String?;
        return ArchUpdateTarget(
          arch: arch,
          version: version,
          filename: name,
          publishedAt: publishedRaw != null
              ? DateTime.tryParse(publishedRaw)
              : null,
        );
      }
    }

    // Single unversioned installer (Windows EXE) → treat as default.
    if (assets.length == 1 &&
        (arch == 'default' || detectArchFromFilename(assets.first) == 'default')) {
      final name = assets.first;
      final version =
          versionFromFilename(name) ??
          (platform['version'] as String?)?.trim().replaceFirst(
            RegExp(r'^v'),
            '',
          );
      if (version == null || version.isEmpty) return null;
      final publishedRaw =
          platform['published_at'] as String? ??
          manifest['published_at'] as String?;
      return ArchUpdateTarget(
        arch: detectArchFromFilename(name),
        version: version,
        filename: name,
        publishedAt: publishedRaw != null
            ? DateTime.tryParse(publishedRaw)
            : null,
      );
    }

    return null;
  }

  static Map<String, dynamic>? _platformEntry(
    Map<String, dynamic> manifest,
    String platformKey,
  ) {
    final platforms = manifest['platforms'];
    if (platforms is Map) {
      final raw = platforms[platformKey];
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
    }

    // Legacy flat → synthetic platform when assets match.
    final version = (manifest['version'] as String?)?.trim().replaceFirst(
      RegExp(r'^v'),
      '',
    );
    final assetsRaw = manifest['assets'];
    if (version == null || version.isEmpty || assetsRaw is! List) return null;
    final assets = <String>[
      for (final a in assetsRaw)
        if (a is String && a.isNotEmpty) a,
    ];
    if (assets.isEmpty) return null;
    return {
      'version': version,
      'assets': assets,
      if (manifest['published_at'] is String)
        'published_at': manifest['published_at'],
    };
  }

  static ArchUpdateTarget? _archEntryFromMap(Map arches, String arch) {
    final raw = arches[arch];
    if (raw is! Map) return null;
    final filename = (raw['filename'] as String?)?.trim();
    final version = (raw['version'] as String?)?.trim().replaceFirst(
      RegExp(r'^v'),
      '',
    );
    if (filename == null ||
        filename.isEmpty ||
        version == null ||
        version.isEmpty) {
      return null;
    }
    final publishedRaw = raw['published_at'] as String?;
    return ArchUpdateTarget(
      arch: arch,
      version: version,
      filename: filename,
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
