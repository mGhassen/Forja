class StreamSource {
  final String url;
  final String title;
  final String type;
  final Map<String, String>? headers;

  /// Anime / provider identity (e.g. `megaplay`, `miruro:kiwi`). Used for
  /// Referer policy and PNG-strip — not CDN hostname matching (RFC-044).
  final String? providerId;

  /// Pre-proxy catalog URL when [url] is a local `/hls-proxy` play endpoint.
  final String? catalogUrl;

  StreamSource({
    required this.url,
    required this.title,
    required this.type,
    this.headers,
    this.providerId,
    this.catalogUrl,
  });

  factory StreamSource.fromJson(Map<String, dynamic> json) {
    Map<String, String>? headers;
    final rawHeaders = json['headers'];
    if (rawHeaders is Map) {
      headers = rawHeaders.map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      );
    }
    final pid = (json['providerId'] as String?)?.trim();
    final catalog = (json['catalogUrl'] as String?)?.trim();
    return StreamSource(
      url: json['url'] ?? json['file'] ?? json['src'] ?? '',
      title: json['title'] ?? json['label'] ?? json['quality'] ?? 'Unknown',
      type: json['type'] ?? 'video',
      headers: headers,
      providerId: (pid != null && pid.isNotEmpty) ? pid : null,
      catalogUrl: (catalog != null && catalog.isNotEmpty) ? catalog : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'title': title,
        'type': type,
        if (headers != null) 'headers': headers,
        if (providerId != null && providerId!.isNotEmpty)
          'providerId': providerId,
        if (catalogUrl != null && catalogUrl!.isNotEmpty)
          'catalogUrl': catalogUrl,
      };

  StreamSource copyWith({
    String? url,
    String? title,
    String? type,
    Map<String, String>? headers,
    String? providerId,
    String? catalogUrl,
    bool clearHeaders = false,
  }) {
    return StreamSource(
      url: url ?? this.url,
      title: title ?? this.title,
      type: type ?? this.type,
      headers: clearHeaders ? null : (headers ?? this.headers),
      providerId: providerId ?? this.providerId,
      catalogUrl: catalogUrl ?? this.catalogUrl,
    );
  }
}

int streamSourcePlayPriority(StreamSource source) {
  final url = source.url.toLowerCase();
  if (url.contains('.m3u8')) return 0;
  if (url.contains('h265') || url.contains('hevc') || url.contains('/h265/')) {
    return 2;
  }
  return 1;
}

/// Collapse duplicate playable URLs and prefer HLS / non-HEVC first.
/// Sync fallback — use [dedupeStreamSourcesAsync] when device profile is available.
List<StreamSource> dedupeStreamSources(List<StreamSource> sources) {
  final seen = <String>{};
  final out = <StreamSource>[];
  for (final source in sources) {
    final url = source.url.trim();
    if (url.isEmpty || !seen.add(url)) continue;
    out.add(source);
  }
  out.sort((a, b) => streamSourcePlayPriority(a).compareTo(
        streamSourcePlayPriority(b),
      ));
  return out;
}

class StreamResult {
  final List<StreamSource> sources;
  final String provider;
  final bool isRateLimited;
  final String? primaryUrl;
  final Map<String, String>? headers;

  StreamResult({
    required this.sources,
    required this.provider,
    this.isRateLimited = false,
    this.primaryUrl,
    this.headers,
  });

  String get url => primaryUrl ?? (sources.isNotEmpty ? sources.first.url : '');
}
