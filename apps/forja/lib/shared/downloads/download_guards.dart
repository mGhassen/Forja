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

/// True when [url] or playback [headers] carry an expired `expires=` / JWT.
///
/// Vixsrc (and similar) gate the CDN with an embed Referer token while the
/// play URL itself has no `expires=` — mid-watch downloads must not reuse it.
bool isDownloadAuthExpired(
  String url, {
  Map<String, String>? headers,
  DateTime? now,
}) {
  if (isStreamUrlTokenExpired(url, now: now)) return true;
  if (headers == null || headers.isEmpty) return false;
  for (final e in headers.entries) {
    final k = e.key.trim().toLowerCase();
    if (k != 'referer' && k != 'origin') continue;
    final v = e.value.trim();
    if (v.isEmpty) continue;
    if (isStreamUrlTokenExpired(v, now: now)) return true;
  }
  return false;
}

/// Whether [url] is a durable HTTP(S) stream that Phase 1 may download.
///
/// Rejects magnets/torrents, DASH MPD, empty URLs, loopback junk, and expired
/// stream tokens (`?token=` JWT / `expires=`). Pass [headers] so embed Referer
/// expiry is checked too.
bool isDownloadableHttpUrl(
  String url, {
  Map<String, String>? headers,
  DateTime? now,
}) {
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

  if (isDownloadAuthExpired(u, headers: headers, now: now)) return false;
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

const String kOfflineDownloadExpiredMessage =
    'Stream link expired — open Sources and download again';

/// User-facing reason when a URL cannot be saved offline.
String? offlineDownloadRejectReason(
  String url, {
  Map<String, String>? headers,
  DateTime? now,
}) {
  final u = url.trim();
  if (u.isEmpty) return 'This stream can’t be saved offline';
  if (isTorrentStreamUrl(u)) {
    return "Torrents aren't available for offline download yet";
  }
  if (isDashManifestUrl(u)) {
    return "DASH streams can't be saved offline yet";
  }
  if (isDownloadAuthExpired(u, headers: headers, now: now)) {
    return kOfflineDownloadExpiredMessage;
  }
  if (!isDownloadableHttpUrl(u, headers: headers, now: now)) {
    return 'This stream can’t be saved offline';
  }
  return null;
}
