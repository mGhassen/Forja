import 'package:flutter/foundation.dart';
import 'package:forja/shared/utils/bounded_parallel.dart';
import 'package:rust/rust.dart';

/// Browser UA — HubCloud workers 403 bare `libmpv` / empty UA.
const _kProbeUa =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36';

/// HubCloud FSL Drive proxy: `*.workers.dev/{hash}::{key}/…/file.mkv`.
bool isHubCloudDriveProxyUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.host.isEmpty) return false;
  if (!uri.host.toLowerCase().endsWith('.workers.dev')) return false;
  return uri.path.contains('::');
}

/// Google Drive `downloadQuotaExceeded` JSON (often served as text/html).
bool isDriveDownloadQuotaBody(String body) {
  final lower = body.toLowerCase();
  return lower.contains('downloadquotaexceeded') ||
      lower.contains('download quota for this file has been exceeded');
}

/// Probe whether a HubCloud Drive-proxy URL is currently Drive-quota blocked.
///
/// Second arg is positional (not named) so it matches [dropHubCloudDriveQuotaRows]'s
/// `quotaCheck` typedef — a named-only tear-off crashes at runtime with
/// `NoSuchMethodError: Closure call with mismatched arguments` and wipes the
/// whole Nuvio scraper result (e.g. UHDMovies returned 6 streams then []).
Future<bool> hubCloudDriveQuotaExceeded(
  String url, [
  Map<String, String>? headers,
]) async {
  if (!isHubCloudDriveProxyUrl(url)) return false;
  try {
    final hdrs = <String, String>{
      'User-Agent': _kProbeUa,
      'Range': 'bytes=0-511',
      if (headers != null)
        for (final e in headers.entries)
          if (e.key.trim().isNotEmpty && e.value.trim().isNotEmpty)
            e.key: e.value,
    };
    final res = await engineHttp(
      'GET',
      url,
      headers: hdrs,
      timeoutSecs: 8,
      maxRetries: 0,
    );
    return isDriveDownloadQuotaBody(res.body);
  } catch (_) {
    return false;
  }
}

/// Drop HubCloud Drive-proxy rows whose Range probe returns Drive quota JSON.
///
/// Non-proxy URLs are kept. Probe failures (timeout / network) keep the row.
Future<List<T>> dropHubCloudDriveQuotaRows<T>({
  required List<T> rows,
  required String Function(T row) urlOf,
  Map<String, String> Function(T row)? headersOf,
  bool Function()? isCancelled,
  Future<bool> Function(String url, Map<String, String>? headers)? quotaCheck,
}) async {
  if (rows.isEmpty) return rows;
  final probeIdx = <int>[
    for (var i = 0; i < rows.length; i++)
      if (isHubCloudDriveProxyUrl(urlOf(rows[i]))) i,
  ];
  if (probeIdx.isEmpty) return rows;

  final check = quotaCheck ?? hubCloudDriveQuotaExceeded;
  final dead = <int>{};
  await mapBoundedParallel<int, int>(
    items: probeIdx,
    concurrency: 6,
    isCancelled: isCancelled,
    work: (i, _) async {
      if (isCancelled?.call() ?? false) return null;
      final exceeded = await check(urlOf(rows[i]), headersOf?.call(rows[i]));
      if (exceeded) {
        dead.add(i);
        return i;
      }
      return null;
    },
  );
  if (dead.isEmpty) return rows;
  debugPrint(
    '[HubCloud] dropped ${dead.length} Drive-quota link(s)',
  );
  return [
    for (var i = 0; i < rows.length; i++)
      if (!dead.contains(i)) rows[i],
  ];
}
