/// URL guards for direct-stream playback and disk cache.
library;

/// A magnet / torrent link — NOT a direct HTTP(S) stream.
bool isTorrentStreamUrl(String url) {
  final u = url.trim().toLowerCase();
  return u.startsWith('magnet:') ||
      u.contains('urn:btih:') ||
      u.endsWith('.torrent');
}

/// Placeholder / relative URLs must never ship in webstreaming session or disk cache.
bool isUnplayableCachedStreamUrl(String url) {
  final u = url.trim();
  if (u.isEmpty) return true;
  if (isTorrentStreamUrl(u)) return true;
  final lower = u.toLowerCase();
  if (lower.contains('demo-video')) return true;
  if (u.startsWith('/') && !u.startsWith('//')) return true;
  if (!u.contains('://')) return true;
  // Loopback play URLs (111477 seek proxy, torrent localhost, …) are session-
  // local — caching or scoring them as catalog streams marks "stream down"
  // when the port dies, while a manual catalog-URL check still passes.
  final host = Uri.tryParse(u)?.host.toLowerCase() ?? '';
  if (host == '127.0.0.1' || host == 'localhost') return true;
  return false;
}
