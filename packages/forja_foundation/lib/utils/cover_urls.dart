/// Absolute / CDN cover URL helpers (no host TMDB client).
library;

/// Hub thumbnail URL normalization (pack-agnostic).
/// Official TMDB image hosts → Forja gateway (`tmdb.forjahq.xyz`).
String normalizeCoverUrl(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return value;
  final uri = Uri.tryParse(value);
  if (uri == null) return paintableNetworkImageUrl(value);
  if (uri.host == 'media.themoviedb.org' || uri.host == 'image.tmdb.org') {
    return paintableNetworkImageUrl(
      uri.replace(host: 'tmdb.forjahq.xyz').toString(),
    );
  }
  return paintableNetworkImageUrl(value);
}

/// Absolute `http(s)` URLs only. Relative `/path` keys stay unchanged
/// (invalid pack data — packs must ship absolute covers).
String resolveAbsoluteCoverUrl(String raw) {
  final value = normalizeCoverUrl(raw.trim());
  if (value.isEmpty) return value;
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }
  return value;
}

/// URL safe for Flutter [Image.network] / Android [ImageDecoder].
///
/// TMDB title logos are often `.svg`. Android cannot decode SVG, so http(s)
/// paths ending in `.svg` are rewritten to `.png` (same asset on TMDB / our
/// gateway). Pack-local `file://` / relative SVGs are left alone — paint those
/// with `SvgPicture`, not [Image.network].
String paintableNetworkImageUrl(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return value;
  final lower = value.toLowerCase();
  final http = lower.startsWith('http://') || lower.startsWith('https://');
  if (!http || !lower.endsWith('.svg')) return value;
  return '${value.substring(0, value.length - 4)}.png';
}
