/// Absolute / CDN cover URL helpers (no host TMDB client).
library;

/// Hub thumbnail URL normalization (pack-agnostic).
String normalizeCoverUrl(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return value;
  final uri = Uri.tryParse(value);
  if (uri == null || uri.host != 'media.themoviedb.org') return value;
  return uri.replace(host: 'image.tmdb.org').toString();
}

/// Absolute `http(s)` URLs only. Relative `/path` keys stay unchanged —
/// host [resolveCoverUrl] expands those via TMDB CDN.
String resolveAbsoluteCoverUrl(String raw) {
  final value = normalizeCoverUrl(raw.trim());
  if (value.isEmpty) return value;
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }
  return value;
}
