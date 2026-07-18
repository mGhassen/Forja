import 'package:forja/shared/supabase/forja_supabase.dart';

/// Public Supabase Storage URLs for release installers (`releases` bucket).
class ReleaseStorageUrls {
  ReleaseStorageUrls._();

  static const String bucket = 'releases';

  /// `{SUPABASE_URL}/storage/v1/object/public/releases/v{version}/{filename}`
  static String? publicUrl({
    required String version,
    required String filename,
  }) {
    final base = ForjaSupabase.url.trim();
    if (base.isEmpty) return null;
    final ver = version.startsWith('v') ? version.substring(1) : version;
    final root = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return '$root/storage/v1/object/public/$bucket/v$ver/$filename';
  }

  /// Prefer Supabase Storage; fall back to the GitHub asset URL.
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
