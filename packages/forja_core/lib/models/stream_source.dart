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
    return StreamSource(
      url: json['url'] ?? json['file'] ?? json['src'] ?? '',
      title: json['title'] ?? json['label'] ?? json['quality'] ?? 'Unknown',
      type: json['type'] ?? 'video',
    );
  }
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
