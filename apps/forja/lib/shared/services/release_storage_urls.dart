/// Public CDN URLs for release installers (Cloudflare R2).
///
/// Pass at run/build time: `--dart-define=RELEASE_CDN_URL=https://…`
///
/// - Latest (in-app update + site): `{RELEASE_CDN_URL}/latest/{filename}`
/// - Versioned (optional): `{RELEASE_CDN_URL}/v{version}/{filename}`
class ReleaseStorageUrls {
  ReleaseStorageUrls._();

  /// Public base URL for installers (no trailing slash). Empty → GitHub fallback.
  static const String cdnBase = String.fromEnvironment('RELEASE_CDN_URL');

  static String? get _root {
    final base = cdnBase.trim();
    if (base.isEmpty) return null;
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  }

  /// `{RELEASE_CDN_URL}/latest/{filename}` — current release mirror.
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

  /// Prefer R2 `latest/`; fall back to the GitHub asset URL.
  static String preferStorage({
    required String version,
    required String filename,
    required String? githubDownloadUrl,
  }) {
    return latestUrl(filename: filename) ??
        publicUrl(version: version, filename: filename) ??
        githubDownloadUrl ??
        '';
  }

  /// True for a direct installer object (CDN, GitHub asset, etc.).
  /// False for HTML release pages — those must open in a browser.
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
