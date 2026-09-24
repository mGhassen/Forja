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

/// True when [bytes] start with a known playable media container magic.
///
/// Rejects leading-zero / garbage heads that mpv reports as
/// "Failed to recognize file format" after a corrupt Range resume.
bool looksLikeMediaContainerBytes(List<int> bytes) {
  if (bytes.length < 4) return false;

  bool matchAt(int offset, int b0, [int? b1, int? b2, int? b3]) {
    if (offset >= bytes.length) return false;
    if (bytes[offset] != b0) return false;
    if (b1 != null &&
        (offset + 1 >= bytes.length || bytes[offset + 1] != b1)) {
      return false;
    }
    if (b2 != null &&
        (offset + 2 >= bytes.length || bytes[offset + 2] != b2)) {
      return false;
    }
    if (b3 != null &&
        (offset + 3 >= bytes.length || bytes[offset + 3] != b3)) {
      return false;
    }
    return true;
  }

  bool hasMagicAt(int offset) {
    // Matroska / WebM EBML
    if (matchAt(offset, 0x1a, 0x45, 0xdf, 0xa3)) return true;
    // ISO BMFF (mp4 / m4v / mov) — size(4) + 'ftyp'
    if (bytes.length - offset >= 8 &&
        matchAt(offset + 4, 0x66, 0x74, 0x79, 0x70)) {
      return true;
    }
    // MPEG-TS sync
    if (matchAt(offset, 0x47)) return true;
    // RIFF (AVI / WAV)
    if (matchAt(offset, 0x52, 0x49, 0x46, 0x46)) return true;
    // Ogg
    if (matchAt(offset, 0x4f, 0x67, 0x67, 0x53)) return true;
    // FLV
    if (matchAt(offset, 0x46, 0x4c, 0x56)) return true;
    // ID3-tagged MPEG
    if (matchAt(offset, 0x49, 0x44, 0x33)) return true;
    // MPEG PES / pack
    if (matchAt(offset, 0x00, 0x00, 0x01)) return true;
    return false;
  }

  if (hasMagicAt(0)) return true;

  // Tiny leading null pad only (not kilobytes of wiped header).
  var offset = 0;
  final maxPad = bytes.length < 16 ? bytes.length : 16;
  while (offset < maxPad && bytes[offset] == 0) {
    offset++;
  }
  if (offset == 0 || offset >= bytes.length - 3) return false;
  return hasMagicAt(offset);
}

/// Preferred file extension from a `Content-Disposition` filename, or null.
String? extensionFromContentDisposition(String? header) {
  if (header == null || header.isEmpty) return null;
  final star = RegExp(
    r'''filename\*\s*=\s*[^']*'[^']*'([^;]+)''',
    caseSensitive: false,
  ).firstMatch(header);
  final plain = RegExp(
    r'''filename\s*=\s*"?([^";]+)"?''',
    caseSensitive: false,
  ).firstMatch(header);
  final name = (star?.group(1) ?? plain?.group(1) ?? '').trim();
  if (name.isEmpty) return null;
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot >= name.length - 1) return null;
  final ext = name.substring(dot).toLowerCase();
  const allowed = {
    '.mp4',
    '.m4v',
    '.mkv',
    '.webm',
    '.mov',
    '.avi',
    '.ts',
    '.m2ts',
    '.mpg',
    '.mpeg',
    '.flv',
  };
  return allowed.contains(ext) ? ext : null;
}

/// Preferred extension from `Content-Type`, or null.
String? extensionFromContentType(String? mime) {
  if (mime == null || mime.isEmpty) return null;
  final m = mime.toLowerCase().split(';').first.trim();
  switch (m) {
    case 'video/matroska':
    case 'video/x-matroska':
      return '.mkv';
    case 'video/webm':
      return '.webm';
    case 'video/mp4':
    case 'video/x-m4v':
      return '.mp4';
    case 'video/quicktime':
      return '.mov';
    case 'video/avi':
    case 'video/x-msvideo':
      return '.avi';
    case 'video/mp2t':
    case 'video/MP2T':
      return '.ts';
    case 'video/x-flv':
      return '.flv';
    default:
      return null;
  }
}

/// Start byte from a `Content-Range: bytes START-END/TOTAL` header, or null.
int? parseContentRangeStart(String? header) {
  if (header == null || header.isEmpty) return null;
  final m = RegExp(
    r'bytes\s+(\d+)\s*-\s*(\d+)\s*/\s*(\d+|\*)',
    caseSensitive: false,
  ).firstMatch(header.trim());
  if (m == null) return null;
  return int.tryParse(m.group(1)!);
}

/// Total size from `Content-Range`, or null when `*` / missing.
int? parseContentRangeTotal(String? header) {
  if (header == null || header.isEmpty) return null;
  final m = RegExp(
    r'bytes\s+(\d+)\s*-\s*(\d+)\s*/\s*(\d+|\*)',
    caseSensitive: false,
  ).firstMatch(header.trim());
  if (m == null) return null;
  final total = m.group(3);
  if (total == null || total == '*') return null;
  return int.tryParse(total);
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
