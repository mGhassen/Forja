/// Public CDN URLs for release installers (Cloudflare R2).
///
/// Pass at run/build time: `--dart-define=RELEASE_CDN_URL=https://…`
///
/// In-app updates:
/// - Discovery: `{RELEASE_CDN_URL}/latest/manifest.json` (per-platform `platforms` map)
/// - Installer: `{RELEASE_CDN_URL}/latest/{filename}` (merged per platform/arch)
/// - Fallback: `{RELEASE_CDN_URL}/v{version}/{filename}` (immutable archive)
/// - Notes: `{RELEASE_CDN_URL}/changelog/index.json` + `changelog/{version}.md`
///
/// `latest/{installer}` is the canonical download path (web + in-app).
/// `changelog/` is a permanent archive (not pruned with installer retention).
class ReleaseStorageUrls {
  ReleaseStorageUrls._();

  /// Public base URL for installers (no trailing slash).
  static const String cdnBase = String.fromEnvironment('RELEASE_CDN_URL');

  static String? get _root {
    final base = cdnBase.trim();
    if (base.isEmpty) return null;
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  }

  /// `{RELEASE_CDN_URL}/latest/manifest.json` - updater discovery.
  static String? manifestUrl() {
    final root = _root;
    if (root == null) return null;
    return '$root/latest/manifest.json';
  }

  /// `{RELEASE_CDN_URL}/changelog/index.json` - version list for update notes.
  static String? changelogIndexUrl() {
    final root = _root;
    if (root == null) return null;
    return '$root/changelog/index.json';
  }

  /// `{RELEASE_CDN_URL}/changelog/{version}.md` - frozen release notes body.
  static String? changelogUrl({required String version}) {
    final root = _root;
    if (root == null) return null;
    final ver = version.startsWith('v') ? version.substring(1) : version;
    return '$root/changelog/$ver.md';
  }

  /// `{RELEASE_CDN_URL}/latest/{filename}` - web CTAs + in-app installer download.
  static String? latestUrl({required String filename}) {
    final root = _root;
    if (root == null) return null;
    return '$root/latest/$filename';
  }

  /// `{RELEASE_CDN_URL}/v{version}/{filename}`
  static String? publicUrl({
    required String version,
    required String filename,
  }) {
    final root = _root;
    if (root == null) return null;
    final ver = version.startsWith('v') ? version.substring(1) : version;
    return '$root/v$ver/$filename';
  }

  /// Prefer merged `latest/{filename}`; fall back to versioned archive.
  ///
  /// [version] is only used for the fallback path — pass the semver embedded
  /// in [filename] when present (split-arch latest can mix versions).
  static String preferStorage({
    required String version,
    required String filename,
  }) {
    final latest = latestUrl(filename: filename);
    if (latest != null && latest.isNotEmpty) return latest;
    return publicUrl(version: version, filename: filename) ?? '';
  }

  /// True for a direct installer object.
  /// False for HTML pages / JSON manifests.
  static bool isDirectInstallerUrl(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    return path.endsWith('.dmg') ||
        path.endsWith('.zip') ||
        path.endsWith('.exe') ||
        path.endsWith('.appimage') ||
        path.endsWith('.apk') ||
        path.endsWith('.deb');
  }
}
