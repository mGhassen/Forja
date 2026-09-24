import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/downloads/download_guards.dart';
import 'package:forja/shared/downloads/hls_download_engine.dart';

/// Result of a pre-download size probe (no file write).
class DownloadSizeProbeResult {
  const DownloadSizeProbeResult({
    required this.bytes,
    required this.estimated,
    required this.kind,
    this.error,
  });

  /// Total bytes when known; `0` when unknown.
  final int bytes;

  /// True when [bytes] is an HLS (or similar) estimate, not Content-Length.
  final bool estimated;

  /// `http` · `hls` · `unknown`
  final String kind;

  /// Probe failure detail (still allow download when [bytes] is 0).
  final String? error;

  bool get hasSize => bytes > 0;

  String get sizeLabel {
    if (!hasSize) return 'Size unknown';
    final formatted = _formatBytes(bytes);
    return estimated ? '~$formatted' : formatted;
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    var count = bytes.toDouble();
    while (count >= 1024 && i < suffixes.length - 1) {
      count /= 1024;
      i++;
    }
    return '${count.toStringAsFixed(i == 0 ? 0 : 2)} ${suffixes[i]}';
  }
}

/// Probes [url] for download size without writing to disk.
///
/// Progressive: `Content-Length` / `Content-Range`.
/// HLS: `BANDWIDTH × Σ EXTINF` (estimate), else first-segment length × count.
Future<DownloadSizeProbeResult> probeDownloadSize({
  required String url,
  Map<String, String>? headers,
}) async {
  final rawUrl = url.trim();
  if (rawUrl.isEmpty || !isDownloadableHttpUrl(rawUrl)) {
    return const DownloadSizeProbeResult(
      bytes: 0,
      estimated: false,
      kind: 'unknown',
      error: 'Not downloadable',
    );
  }

  final hdrs = Map<String, String>.from(headers ?? {});
  if (!hdrs.containsKey('User-Agent')) {
    hdrs['User-Agent'] =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
  }

  try {
    if (HlsDownloadEngine.isHlsUrl(rawUrl)) {
      return await _probeHls(Uri.parse(rawUrl), hdrs);
    }

    final progressive = await _probeProgressive(Uri.parse(rawUrl), hdrs);
    if (progressive != null) return progressive;

    // URL didn't look like HLS but body/type did — fall through handled inside.
    return const DownloadSizeProbeResult(
      bytes: 0,
      estimated: false,
      kind: 'unknown',
    );
  } catch (e) {
    debugPrint('[DownloadSizeProbe] $e');
    return DownloadSizeProbeResult(
      bytes: 0,
      estimated: false,
      kind: 'unknown',
      error: e.toString(),
    );
  }
}

Future<DownloadSizeProbeResult?> _probeProgressive(
  Uri uri,
  Map<String, String> headers,
) async {
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 12);
  try {
    // Prefer HEAD — cheap when CDN supports it.
    var length = await _contentLengthVia(
      client,
      uri,
      headers,
      method: 'HEAD',
    );
    if (length != null && length.hls) {
      return await _probeHls(uri, headers);
    }
    if (length != null && length.dash) {
      return const DownloadSizeProbeResult(
        bytes: 0,
        estimated: false,
        kind: 'unknown',
        error: 'DASH',
      );
    }
    if (length != null && length.bytes > 0) {
      return DownloadSizeProbeResult(
        bytes: length.bytes,
        estimated: false,
        kind: 'http',
      );
    }

    // Range GET — many CDNs answer Content-Range without a full body.
    length = await _contentLengthVia(
      client,
      uri,
      headers,
      method: 'GET',
      range: 'bytes=0-0',
    );
    if (length != null && length.hls) {
      return await _probeHls(uri, headers);
    }
    if (length != null && length.dash) {
      return const DownloadSizeProbeResult(
        bytes: 0,
        estimated: false,
        kind: 'unknown',
        error: 'DASH',
      );
    }
    if (length != null && length.bytes > 0) {
      return DownloadSizeProbeResult(
        bytes: length.bytes,
        estimated: false,
        kind: 'http',
      );
    }

    // Last resort: full GET, sniff first bytes (tiny manifests) or Content-Length.
    final req = await client.getUrl(uri);
    headers.forEach((k, v) => req.headers.set(k, v));
    final res = await req.close().timeout(const Duration(seconds: 15));
    final ct = (res.headers.contentType?.mimeType ?? '').toLowerCase();
    if (_isHlsContentType(ct)) {
      final text = await res.transform(utf8.decoder).join();
      client.close(force: true);
      return _estimateFromHlsManifest(uri, text, headers);
    }
    if (_isDashContentType(ct)) {
      await res.drain<void>();
      return const DownloadSizeProbeResult(
        bytes: 0,
        estimated: false,
        kind: 'unknown',
        error: 'DASH',
      );
    }

    final cl = res.contentLength;
    if (cl > 0) {
      await res.drain<void>();
      return DownloadSizeProbeResult(
        bytes: cl,
        estimated: false,
        kind: 'http',
      );
    }

    // Sniff playlist without downloading the whole file.
    final head = <int>[];
    await for (final chunk in res) {
      head.addAll(chunk);
      if (head.length >= 64) break;
    }
    await res.drain<void>();
    if (looksLikeManifestBytes(head)) {
      final text = utf8.decode(head, allowMalformed: true);
      if (text.trimLeft().toUpperCase().startsWith('#EXTM3U')) {
        // Need the full playlist — fetch again as text.
        return await _probeHls(uri, headers);
      }
      return const DownloadSizeProbeResult(
        bytes: 0,
        estimated: false,
        kind: 'unknown',
        error: 'DASH',
      );
    }
    return null;
  } finally {
    client.close(force: true);
  }
}

class _LengthProbe {
  const _LengthProbe({
    required this.bytes,
    this.hls = false,
    this.dash = false,
  });
  final int bytes;
  final bool hls;
  final bool dash;
}

Future<_LengthProbe?> _contentLengthVia(
  HttpClient client,
  Uri uri,
  Map<String, String> headers, {
  required String method,
  String? range,
}) async {
  try {
    final req = await client.openUrl(method, uri);
    headers.forEach((k, v) => req.headers.set(k, v));
    if (range != null) req.headers.set('Range', range);
    final res = await req.close().timeout(const Duration(seconds: 12));
    final ct = (res.headers.contentType?.mimeType ?? '').toLowerCase();
    if (_isHlsContentType(ct)) {
      await res.drain<void>();
      return const _LengthProbe(bytes: 0, hls: true);
    }
    if (_isDashContentType(ct)) {
      await res.drain<void>();
      return const _LengthProbe(bytes: 0, dash: true);
    }

    var bytes = res.contentLength;
    if (bytes <= 0) {
      final cr = res.headers.value('content-range');
      // bytes 0-0/12345678
      final m = RegExp(r'/(\d+)\s*$').firstMatch(cr ?? '');
      if (m != null) bytes = int.tryParse(m.group(1)!) ?? 0;
    }
    await res.drain<void>();
    if (bytes > 0) return _LengthProbe(bytes: bytes);
  } catch (e) {
    debugPrint('[DownloadSizeProbe] $method failed: $e');
  }
  return null;
}

bool _isHlsContentType(String ct) =>
    ct.contains('mpegurl') ||
    ct.contains('x-mpegurl') ||
    ct.contains('apple.mpegurl');

bool _isDashContentType(String ct) =>
    ct.contains('dash+xml') || ct.contains('application/dash');

Future<DownloadSizeProbeResult> _probeHls(
  Uri uri,
  Map<String, String> headers,
) async {
  final text = await _fetchText(uri, headers);
  return _estimateFromHlsManifest(uri, text, headers);
}

Future<DownloadSizeProbeResult> _estimateFromHlsManifest(
  Uri baseUri,
  String manifestText,
  Map<String, String> headers,
) async {
  if (!manifestText.contains('#EXTM3U')) {
    return const DownloadSizeProbeResult(
      bytes: 0,
      estimated: false,
      kind: 'unknown',
      error: 'Not HLS',
    );
  }

  var mediaUri = baseUri;
  var mediaText = manifestText;
  var bandwidth = 0;

  if (manifestText.contains('#EXT-X-STREAM-INF')) {
    final best = _bestVariant(baseUri, manifestText);
    if (best != null) {
      mediaUri = best.uri;
      bandwidth = best.bandwidth;
      mediaText = await _fetchText(mediaUri, headers);
    }
  }

  final durationSec = _sumExtinfSeconds(mediaText);
  final segmentCount = _countMediaSegments(mediaText);

  if (bandwidth > 0 && durationSec > 0) {
    final bytes = ((bandwidth / 8.0) * durationSec).round();
    if (bytes > 0) {
      return DownloadSizeProbeResult(
        bytes: bytes,
        estimated: true,
        kind: 'hls',
      );
    }
  }

  // Fallback: sample first segment length × count.
  if (segmentCount > 0) {
    final firstSeg = _firstSegmentUri(mediaUri, mediaText);
    if (firstSeg != null) {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      try {
        final length = await _contentLengthVia(
          client,
          firstSeg,
          headers,
          method: 'HEAD',
        );
        var segBytes = length?.bytes ?? 0;
        if (segBytes <= 0) {
          final ranged = await _contentLengthVia(
            client,
            firstSeg,
            headers,
            method: 'GET',
            range: 'bytes=0-0',
          );
          segBytes = ranged?.bytes ?? 0;
        }
        if (segBytes > 0) {
          return DownloadSizeProbeResult(
            bytes: segBytes * segmentCount,
            estimated: true,
            kind: 'hls',
          );
        }
      } finally {
        client.close(force: true);
      }
    }
  }

  return const DownloadSizeProbeResult(
    bytes: 0,
    estimated: true,
    kind: 'hls',
  );
}

class _HlsVariant {
  const _HlsVariant({required this.uri, required this.bandwidth});
  final Uri uri;
  final int bandwidth;
}

_HlsVariant? _bestVariant(Uri baseUri, String manifestText) {
  final lines = manifestText.split('\n');
  var highest = -1;
  _HlsVariant? best;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (!line.startsWith('#EXT-X-STREAM-INF')) continue;
    var bandwidth = 0;
    final bwMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(line);
    if (bwMatch != null) {
      bandwidth = int.tryParse(bwMatch.group(1) ?? '') ?? 0;
    }
    for (var j = i + 1; j < lines.length; j++) {
      final sub = lines[j].trim();
      if (sub.isEmpty || sub.startsWith('#')) continue;
      if (bandwidth > highest || best == null) {
        highest = bandwidth;
        best = _HlsVariant(uri: baseUri.resolve(sub), bandwidth: bandwidth);
      }
      break;
    }
  }
  return best;
}

double _sumExtinfSeconds(String manifestText) {
  var total = 0.0;
  for (final line in manifestText.split('\n')) {
    final t = line.trim();
    if (!t.startsWith('#EXTINF:')) continue;
    final m = RegExp(r'#EXTINF:([\d.]+)').firstMatch(t);
    if (m != null) {
      total += double.tryParse(m.group(1)!) ?? 0;
    }
  }
  return total;
}

int _countMediaSegments(String manifestText) {
  var count = 0;
  final lines = manifestText.split('\n');
  for (var i = 0; i < lines.length; i++) {
    if (!lines[i].trim().startsWith('#EXTINF:')) continue;
    for (var j = i + 1; j < lines.length; j++) {
      final sub = lines[j].trim();
      if (sub.isEmpty) continue;
      if (sub.startsWith('#')) break;
      count++;
      break;
    }
  }
  return count;
}

Uri? _firstSegmentUri(Uri baseUri, String manifestText) {
  final lines = manifestText.split('\n');
  for (var i = 0; i < lines.length; i++) {
    if (!lines[i].trim().startsWith('#EXTINF:')) continue;
    for (var j = i + 1; j < lines.length; j++) {
      final sub = lines[j].trim();
      if (sub.isEmpty) continue;
      if (sub.startsWith('#')) break;
      return baseUri.resolve(sub);
    }
  }
  return null;
}

Future<String> _fetchText(Uri uri, Map<String, String> headers) async {
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 12);
  try {
    final req = await client.getUrl(uri);
    headers.forEach((k, v) => req.headers.set(k, v));
    final res = await req.close().timeout(const Duration(seconds: 15));
    if (res.statusCode != 200 && res.statusCode != 206) {
      throw Exception('HTTP ${res.statusCode}');
    }
    final bytes = await res.fold<List<int>>([], (p, e) => p..addAll(e));
    return utf8.decode(bytes, allowMalformed: true);
  } finally {
    client.close(force: true);
  }
}
