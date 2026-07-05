import 'dart:convert';

import '../errors.dart';
import '../types.dart';

/// Optional Rust HTML extractor hooks. Set from app bootstrap when [ForjaEngine] loads.
abstract final class WebstreamrParseBackend {
  static String? Function(String extractorId, String html, String pageUrl)?
      extractEmbedHtmlJson;
  static String? Function(String outerHtml, String rcpHtml, String prorcpHtml)?
      extractVidsrcChainJson;
}

List<InternalUrlResult>? _mapDecoded(
  Map<String, dynamic> decoded,
  Meta meta,
) {
  if (decoded['error'] != null) throw NotFoundError();

  final urlStr = decoded['url'] as String?;
  if (urlStr == null || urlStr.isEmpty) throw NotFoundError();

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

  Map<String, String>? requestHeaders;
  final rh = decoded['request_headers'];
  if (rh is Map) {
    requestHeaders = rh.map((k, v) => MapEntry('$k', '$v'));
  }

  final ytId = decoded['yt_id'] as String?;

  return [
    InternalUrlResult(
      url: Uri.parse(urlStr),
      format: format,
      ytId: ytId,
      meta: out,
      requestHeaders: requestHeaders,
    ),
  ];
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

  final decoded = jsonDecode(backend(extractorId, html, pageUrl));
  if (decoded is! Map<String, dynamic>) {
    throw StateError('WebstreamrParseBackend: invalid JSON');
  }
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

  final decoded = jsonDecode(backend(outerHtml, rcpHtml, prorcpHtml));
  if (decoded is! Map<String, dynamic>) {
    throw StateError('WebstreamrParseBackend: invalid JSON');
  }
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
