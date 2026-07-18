/// Public CDN URLs for release installers (Cloudflare R2).
///
/// Pass at run/build time: `--dart-define=RELEASE_CDN_URL=https://…`
/// Objects: `{RELEASE_CDN_URL}/v{version}/{filename}`
class ReleaseStorageUrls {
  ReleaseStorageUrls._();

  /// Public base URL for installers (no trailing slash). Empty → GitHub fallback.
  static const String cdnBase = String.fromEnvironment('RELEASE_CDN_URL');

  /// `{RELEASE_CDN_URL}/v{version}/{filename}`
  static String? publicUrl({
    required String version,
    required String filename,
  }) {
    final base = cdnBase.trim();
    if (base.isEmpty) return null;
    final ver = version.startsWith('v') ? version.substring(1) : version;
    final root = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return '$root/v$ver/$filename';
  }

  /// Prefer R2 CDN; fall back to the GitHub asset URL.
  static String preferStorage({
    required String version,
    required String filename,
    required String? githubDownloadUrl,
  }) {
    return publicUrl(version: version, filename: filename) ??
        githubDownloadUrl ??
        '';
  }
}
