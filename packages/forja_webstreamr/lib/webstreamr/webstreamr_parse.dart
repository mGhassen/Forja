import 'dart:convert';

import 'errors.dart';
import 'types.dart';
import 'utils/id.dart';

/// Optional Rust HTML extractor hooks. Set from app bootstrap when [ForjaEngine] loads.
abstract final class WebstreamrParseBackend {
  static String? Function(String extractorId, String html, String pageUrl)?
      extractEmbedHtmlJson;
  static String? Function(String outerHtml, String rcpHtml, String prorcpHtml)?
      extractVidsrcChainJson;
  static String? Function(String linksHtml, String pageUrl)?
      extractHubcloudLinksJson;
  static String? Function(
    String extractorId,
    String html,
    String pageUrl,
    String mfpConfigJson,
    String extraHtml,
  )? extractMfpEmbedHtmlJson;
  static String? Function(String sourceId, String requestJson)? resolveSourceJson;
  static String? Function(String html, int seasonIndex, int episodeIndex)?
      extractKinogerEpisodeUrlsJson;
  static String? Function(String sourceId, String html, String optsJson)?
      parseSourceHtmlJson;
}

Map<String, dynamic>? _decodeRust(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw StateError('WebstreamrParseBackend: invalid JSON');
  }
  return decoded;
}

Map<String, dynamic> _sourceRequestJson(
  String type,
  Id id, {
  String? title,
  int? year,
}) {
  final isMovie = type == 'movie';
  return {
    'media_type': isMovie ? 'movie' : 'series',
    if (id is ImdbId) 'imdb_id': id.id,
    if (id is TmdbId) 'tmdb_id': id.id,
    if (id.season != null) 'season': id.season,
    if (id.episode != null) 'episode': id.episode,
    if (title != null && title.isNotEmpty) 'title': title,
    if (year != null) 'year': year,
  };
}

List<SourceResult>? _sourceResultsFromJson(dynamic decoded) {
  if (decoded is! List || decoded.isEmpty) return null;
  final out = <SourceResult>[];
  for (final item in decoded) {
    if (item is! Map<String, dynamic>) continue;
    final url = item['url'] as String?;
    if (url == null || url.isEmpty) continue;
    final ccs = <CountryCode>[];
    final rawCcs = item['country_codes'];
    if (rawCcs is List) {
      for (final cc in rawCcs) {
        final parsed = countryCodeFromString('$cc');
        if (parsed != null) ccs.add(parsed);
      }
    }
    out.add(SourceResult(
      url: Uri.parse(url),
      meta: Meta(
        title: item['title'] as String?,
        referer: item['referer'] as String?,
        countryCodes: ccs.isEmpty ? null : ccs,
        priority: item['priority'] as int?,
      ),
    ));
  }
  return out.isEmpty ? null : out;
}

List<SourceResult>? tryRustResolveSource(
  String sourceId,
  String type,
  Id id, {
  String? title,
  int? year,
}) {
  final backend = WebstreamrParseBackend.resolveSourceJson;
  if (backend == null) return null;

  final raw = backend(sourceId, jsonEncode(_sourceRequestJson(type, id, title: title, year: year)));
  if (raw == null) return null;
  return _sourceResultsFromJson(jsonDecode(raw));
}

List<SourceResult>? tryRustParseSourceHtml(
  String sourceId,
  String html, {
  required String referer,
}) {
  final backend = WebstreamrParseBackend.parseSourceHtmlJson;
  if (backend == null) return null;
  final raw = backend(sourceId, html, jsonEncode({'referer': referer}));
  if (raw == null) return null;
  return _sourceResultsFromJson(jsonDecode(raw));
}

List<Uri>? tryRustKinogerEpisodeUrls(
  String html,
  int seasonIndex,
  int episodeIndex,
) {
  final backend = WebstreamrParseBackend.extractKinogerEpisodeUrlsJson;
  if (backend == null) return null;
  final raw = backend(html, seasonIndex, episodeIndex);
  if (raw == null) return null;
  final decoded = jsonDecode(raw);
  if (decoded is! List || decoded.isEmpty) return null;
  return decoded
      .whereType<String>()
      .where((u) => u.isNotEmpty)
      .map(Uri.parse)
      .toList();
}

/// Returns a follow-up embed URL when Rust found an iframe/redirect hop.
String? tryRustNextUrl(String extractorId, String html, String pageUrl) {
  final backend = WebstreamrParseBackend.extractEmbedHtmlJson;
  if (backend == null) return null;
  final raw = backend(extractorId, html, pageUrl);
  if (raw == null) return null;
  final decoded = _decodeRust(raw);
  if (decoded == null) return null;
  return decoded['next_url'] as String?;
}

List<InternalUrlResult>? _mapDecoded(
  Map<String, dynamic> decoded,
  Meta meta,
) {
  if (decoded['error'] != null) throw NotFoundError();

  final urlStr = decoded['url'] as String?;
  if (urlStr == null || urlStr.isEmpty) return null;

  final format = switch (decoded['format'] as String? ?? 'unknown') {
    'hls' => Format.hls,
    'mp4' => Format.mp4,
    _ => Format.unknown,
  };

  final out = meta.clone();
  final title = decoded['title'];
  if (title is String && title.isNotEmpty) out.title = title;
  final height = decoded['height'];
  if (height is int) out.height = height;
  final bytes = decoded['bytes'];
  if (bytes is int) out.bytes = bytes;
  final extractorId = decoded['meta_extractor_id'];
  if (extractorId is String && extractorId.isNotEmpty) {
    out.extractorId = extractorId;
  }

  Map<String, String>? requestHeaders;
  final rh = decoded['request_headers'];
  if (rh is Map) {
    requestHeaders = rh.map((k, v) => MapEntry('$k', '$v'));
  }

  final ytId = decoded['yt_id'] as String?;
  final isExternal = decoded['is_external'] == true;

  return [
    InternalUrlResult(
      url: Uri.parse(urlStr),
      format: format,
      isExternal: isExternal,
      ytId: ytId,
      label: decoded['label'] as String?,
      meta: out,
      requestHeaders: requestHeaders,
    ),
  ];
}

List<InternalUrlResult>? tryRustExtractHubcloudLinks(
  String linksHtml,
  String pageUrl,
  Meta meta,
) {
  final backend = WebstreamrParseBackend.extractHubcloudLinksJson;
  if (backend == null) return null;

  final raw = backend(linksHtml, pageUrl);
  if (raw == null) return null;
  final decoded = jsonDecode(raw);
  if (decoded is! List) return null;

  final out = <InternalUrlResult>[];
  for (final item in decoded) {
    if (item is! Map<String, dynamic>) continue;
    final rows = _mapDecoded(item, meta);
    if (rows != null) out.addAll(rows);
  }
  return out.isEmpty ? null : out;
}

/// MFP redirect extractors need proxy config from [Context].
List<InternalUrlResult>? tryRustExtractMfpFromHtml(
  String extractorId,
  String html,
  String pageUrl,
  Meta meta,
  String mfpConfigJson, {
  String extraHtml = '',
}) {
  final backend = WebstreamrParseBackend.extractMfpEmbedHtmlJson;
  if (backend == null) return null;

  final raw = backend(extractorId, html, pageUrl, mfpConfigJson, extraHtml);
  if (raw == null) return null;
  final decoded = _decodeRust(raw);
  if (decoded == null) return null;
  if (decoded['next_url'] != null) return null;
  return _mapDecoded(decoded, meta);
}

/// Returns parsed stream rows when the Rust backend is installed; otherwise `null`
/// so callers fall back to the Dart extractor body.
List<InternalUrlResult>? tryRustExtractFromHtml(
  String extractorId,
  String html,
  String pageUrl,
  Meta meta,
) {
  final backend = WebstreamrParseBackend.extractEmbedHtmlJson;
  if (backend == null) return null;

  final raw = backend(extractorId, html, pageUrl);
  if (raw == null) return null;
  final decoded = _decodeRust(raw);
  if (decoded == null) return null;
  if (decoded['next_url'] != null) return null;
  return _mapDecoded(decoded, meta);
}

List<InternalUrlResult>? tryRustVidsrcChain(
  String outerHtml,
  String rcpHtml,
  String prorcpHtml,
  Meta meta, {
  String? label,
}) {
  final backend = WebstreamrParseBackend.extractVidsrcChainJson;
  if (backend == null) return null;

  final raw = backend(outerHtml, rcpHtml, prorcpHtml);
  if (raw == null) return null;
  final decoded = _decodeRust(raw);
  if (decoded == null) return null;
  final rows = _mapDecoded(decoded, meta);
  if (rows == null || label == null) return rows;
  return rows
      .map((r) => InternalUrlResult(
            url: r.url,
            format: r.format,
            isExternal: r.isExternal,
            ytId: r.ytId,
            error: r.error,
            label: label,
            meta: r.meta,
            requestHeaders: r.requestHeaders,
          ))
      .toList();
}
