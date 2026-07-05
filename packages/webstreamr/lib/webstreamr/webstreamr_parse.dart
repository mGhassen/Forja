import 'dart:convert';

import 'package:rust/rust.dart';

import 'errors.dart';
import 'types.dart';
import 'utils/id.dart';

bool get _rustReady => ForjaRust.isInitialized;

Map<String, dynamic>? _decodeRust(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw StateError('Webstreamr parse: invalid JSON');
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
        height: (item['height'] as num?)?.toInt(),
        bytes: (item['bytes'] as num?)?.toInt(),
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
  if (!_rustReady) return null;

  final raw = ForjaRust.instance.resolveWebstreamrSourceJson(
    sourceId,
    jsonEncode(_sourceRequestJson(type, id, title: title, year: year)),
  );
  return _sourceResultsFromJson(jsonDecode(raw));
}

List<SourceResult>? tryRustParseSourceHtml(
  String sourceId,
  String html, {
  required String referer,
  String? title,
  int? season,
  int? episode,
  List<CountryCode>? countryCodes,
  bool? isSeries,
  int? year,
  String? baseUrl,
  String? bodyKind,
}) {
  if (!_rustReady) return null;
  final raw = ForjaRust.instance.parseWebstreamrSourceHtmlJson(
    sourceId,
    html,
    jsonEncode({
      'referer': referer,
      if (title != null && title.isNotEmpty) 'title': title,
      if (season != null) 'season': season,
      if (episode != null) 'episode': episode,
      if (countryCodes != null && countryCodes.isNotEmpty)
        'country_codes': countryCodes.map((c) => c.name).toList(),
      if (isSeries != null) 'is_series': isSeries,
      if (year != null) 'year': year,
      if (baseUrl != null && baseUrl.isNotEmpty) 'base_url': baseUrl,
      if (bodyKind != null && bodyKind.isNotEmpty) 'body_kind': bodyKind,
    }),
  );
  return _sourceResultsFromJson(jsonDecode(raw));
}

List<Uri>? tryRustKinogerEpisodeUrls(
  String html,
  int seasonIndex,
  int episodeIndex,
) {
  if (!_rustReady) return null;
  final raw = ForjaRust.instance.extractKinogerEpisodeUrlsJson(
    html,
    seasonIndex,
    episodeIndex,
  );
  final decoded = jsonDecode(raw);
  if (decoded is! List || decoded.isEmpty) return null;
  return decoded
      .whereType<String>()
      .where((u) => u.isNotEmpty)
      .map(Uri.parse)
      .toList();
}

String? tryRustNextUrl(String extractorId, String html, String pageUrl) {
  if (!_rustReady) return null;
  final raw =
      ForjaRust.instance.extractEmbedHtmlJson(extractorId, html, pageUrl);
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
  if (!_rustReady) return null;

  final raw = ForjaRust.instance.extractHubcloudLinksJson(linksHtml, pageUrl);
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

List<InternalUrlResult>? tryRustExtractMfpFromHtml(
  String extractorId,
  String html,
  String pageUrl,
  Meta meta,
  String mfpConfigJson, {
  String extraHtml = '',
}) {
  if (!_rustReady) return null;

  final raw = ForjaRust.instance.extractMfpEmbedHtmlJson(
    extractorId,
    html,
    pageUrl,
    mfpConfigJson,
    extraHtml: extraHtml,
  );
  final decoded = _decodeRust(raw);
  if (decoded == null) return null;
  if (decoded['next_url'] != null) return null;
  return _mapDecoded(decoded, meta);
}

List<InternalUrlResult>? tryRustExtractFromHtml(
  String extractorId,
  String html,
  String pageUrl,
  Meta meta,
) {
  if (!_rustReady) return null;

  final raw = ForjaRust.instance.extractEmbedHtmlJson(extractorId, html, pageUrl);
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
  if (!_rustReady) return null;

  final raw = ForjaRust.instance.extractVidsrcChainJson(
    outerHtml,
    rcpHtml,
    prorcpHtml,
  );
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

Never _rustRequired(String label) =>
    throw StateError('$label — ForjaEngine not initialized');

List<InternalUrlResult> requireRustExtractFromHtml(
  String extractorId,
  String html,
  String pageUrl,
  Meta meta,
) {
  final rows = tryRustExtractFromHtml(extractorId, html, pageUrl, meta);
  if (rows == null) {
    if (!_rustReady) _rustRequired('extractEmbedHtmlJson');
    throw NotFoundError();
  }
  return rows;
}

List<SourceResult> requireRustParseSourceHtml(
  String sourceId,
  String html, {
  required String referer,
  String? title,
  int? season,
  int? episode,
  List<CountryCode>? countryCodes,
  bool? isSeries,
  int? year,
  String? baseUrl,
  String? bodyKind,
}) {
  final rows = tryRustParseSourceHtml(
    sourceId,
    html,
    referer: referer,
    title: title,
    season: season,
    episode: episode,
    countryCodes: countryCodes,
    isSeries: isSeries,
    year: year,
    baseUrl: baseUrl,
    bodyKind: bodyKind,
  );
  if (rows == null) throw NotFoundError();
  return rows;
}

List<SourceResult> requireRustResolveSource(
  String sourceId,
  String type,
  Id id, {
  String? title,
  int? year,
}) {
  final rows = tryRustResolveSource(
    sourceId,
    type,
    id,
    title: title,
    year: year,
  );
  if (rows == null) {
    if (!_rustReady) _rustRequired('resolveSourceJson');
    throw NotFoundError();
  }
  return rows;
}

String requireRustNextUrl(String extractorId, String html, String pageUrl) {
  final next = tryRustNextUrl(extractorId, html, pageUrl);
  if (next == null || next.isEmpty) throw NotFoundError();
  return next;
}

List<InternalUrlResult> requireRustExtractHubcloudLinks(
  String linksHtml,
  String pageUrl,
  Meta meta,
) {
  final rows = tryRustExtractHubcloudLinks(linksHtml, pageUrl, meta);
  if (rows == null) throw NotFoundError();
  return rows;
}

List<InternalUrlResult> requireRustExtractMfpFromHtml(
  String extractorId,
  String html,
  String pageUrl,
  Meta meta,
  String mfpConfigJson, {
  String extraHtml = '',
}) {
  final rows = tryRustExtractMfpFromHtml(
    extractorId,
    html,
    pageUrl,
    meta,
    mfpConfigJson,
    extraHtml: extraHtml,
  );
  if (rows == null) {
    if (!_rustReady) _rustRequired('extractMfpEmbedHtmlJson');
    throw NotFoundError();
  }
  return rows;
}

List<InternalUrlResult> requireRustVidsrcChain(
  String outerHtml,
  String rcpHtml,
  String prorcpHtml,
  Meta meta, {
  String? label,
}) {
  final rows = tryRustVidsrcChain(
    outerHtml,
    rcpHtml,
    prorcpHtml,
    meta,
    label: label,
  );
  if (rows == null) throw NotFoundError();
  return rows;
}

List<Uri> requireRustKinogerEpisodeUrls(
  String html,
  int seasonIndex,
  int episodeIndex,
) {
  final urls = tryRustKinogerEpisodeUrls(html, seasonIndex, episodeIndex);
  if (urls == null) throw NotFoundError();
  return urls;
}
