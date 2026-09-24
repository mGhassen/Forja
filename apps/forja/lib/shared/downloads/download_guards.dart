import 'package:forja/shared/playback/probe/playback_stream_guards.dart';

/// Whether [url] looks like a DASH MPD (not Phase-1 offline).
bool isDashManifestUrl(String url) {
  final lower = url.trim().toLowerCase();
  if (lower.isEmpty) return false;
  if (lower.contains('.mpd')) return true;
  if (lower.contains('/dash/') || lower.contains('manifest.mpd')) return true;
  if (lower.contains('format=mpd') || lower.contains('type=dash')) return true;
  return false;
}

/// Whether [url] is a durable HTTP(S) stream that Phase 1 may download.
///
/// Rejects magnets/torrents, DASH MPD, empty URLs, loopback junk, and expired
/// stream tokens (`?token=` JWT / `expires=`).
bool isDownloadableHttpUrl(String url) {
  final u = url.trim();
  if (u.isEmpty) return false;
  if (isTorrentStreamUrl(u)) return false;
  if (isDashManifestUrl(u)) return false;

  final lower = u.toLowerCase();
  if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
    return false;
  }

  final uri = Uri.tryParse(u);
  if (uri == null) return false;

  final host = uri.host.toLowerCase();
  if (host == '127.0.0.1' || host == 'localhost') {
    // Loopback play proxies are session-local — not durable download targets.
    return false;
  }

  if (isStreamUrlTokenExpired(u)) return false;
  return true;
}

/// True when [bytes] are a playlist/manifest, not a media container.
bool looksLikeManifestBytes(List<int> bytes) {
  if (bytes.isEmpty) return false;
  final sampleLen = bytes.length < 512 ? bytes.length : 512;
  final head = String.fromCharCodes(bytes.sublist(0, sampleLen)).trimLeft();
  final lower = head.toLowerCase();
  if (lower.startsWith('#extm3u')) return true;
  if (lower.startsWith('<?xml') && lower.contains('mpd')) return true;
  if (lower.startsWith('<mpd')) return true;
  if (lower.startsWith('<!doctype html') || lower.startsWith('<html')) {
    return true;
  }
  return false;
}

/// User-facing reason when a URL cannot be saved offline.
String? offlineDownloadRejectReason(String url) {
  final u = url.trim();
  if (u.isEmpty) return 'This stream can’t be saved offline';
  if (isTorrentStreamUrl(u)) {
    return "Torrents aren't available for offline download yet";
  }
  if (isDashManifestUrl(u)) {
    return "DASH streams can't be saved offline yet";
  }
  if (!isDownloadableHttpUrl(u)) {
    return 'This stream can’t be saved offline';
  }
  return null;
}
