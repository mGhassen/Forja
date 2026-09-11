import 'package:rust/rust.dart';
import 'package:forja_foundation/utils/cover_urls.dart';

export 'package:forja_foundation/utils/cover_urls.dart' show normalizeCoverUrl;

/// CDN URLs, TMDB `/path.jpg` keys, and legacy bare paths → loadable URL.
///
/// Absolute URLs use package [normalizeCoverUrl] / [resolveAbsoluteCoverUrl].
/// Relative `/` keys stay host-owned (TMDB CDN via [TmdbApi]).
String resolveCoverUrl(String raw) {
  final value = normalizeCoverUrl(raw.trim());
  if (value.isEmpty) return value;
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }
  if (value.startsWith('/')) return TmdbApi.getImageUrl(value);
  return value;
}
