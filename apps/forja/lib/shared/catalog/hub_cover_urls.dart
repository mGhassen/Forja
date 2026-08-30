import 'package:rust/rust.dart';

/// Hub thumbnail URL normalization (pack-agnostic).
String normalizeHubCoverUrl(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return value;
  final uri = Uri.tryParse(value);
  if (uri == null || uri.host != 'media.themoviedb.org') return value;
  return uri.replace(host: 'image.tmdb.org').toString();
}

/// CDN URLs, TMDB `/path.jpg` keys, and legacy bare paths → loadable URL.
String resolveHubCoverUrl(String raw) {
  final value = normalizeHubCoverUrl(raw.trim());
  if (value.isEmpty) return value;
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }
  if (value.startsWith('/')) return TmdbApi.getImageUrl(value);
  return value;
}
