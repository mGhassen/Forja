import 'package:api/models/stream_source.dart';

class ExtractedMedia {
  const ExtractedMedia({
    required this.url,
    this.audioUrl,
    required this.headers,
    this.sources,
    this.provider,
    this.externalSubtitles,
  });

  final String url;
  final String? audioUrl;
  final Map<String, String> headers;
  final List<StreamSource>? sources;
  final String? provider;
  final List<Map<String, dynamic>>? externalSubtitles;
}
