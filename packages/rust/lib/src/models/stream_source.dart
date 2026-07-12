class StreamSource {
  final String url;
  final String title;
  final String type;
  final Map<String, String>? headers;

  StreamSource({
    required this.url,
    required this.title,
    required this.type,
    this.headers,
  });

  factory StreamSource.fromJson(Map<String, dynamic> json) {
    Map<String, String>? headers;
    final rawHeaders = json['headers'];
    if (rawHeaders is Map) {
      headers = rawHeaders.map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      );
    }
    return StreamSource(
      url: json['url'] ?? json['file'] ?? json['src'] ?? '',
      title: json['title'] ?? json['label'] ?? json['quality'] ?? 'Unknown',
      type: json['type'] ?? 'video',
      headers: headers,
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'title': title,
        'type': type,
        if (headers != null) 'headers': headers,
      };
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
