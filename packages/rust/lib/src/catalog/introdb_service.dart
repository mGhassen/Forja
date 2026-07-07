import '../metadata_http.dart';

class IntroDbTimestamp {
  final int? startMs;
  final int? endMs;

  IntroDbTimestamp({this.startMs, this.endMs});

  factory IntroDbTimestamp.fromEngineJson(Map<String, dynamic> json) {
    return IntroDbTimestamp(
      startMs: json['start_ms'] as int?,
      endMs: json['end_ms'] as int?,
    );
  }

  Duration? get start => startMs != null ? Duration(milliseconds: startMs!) : null;
  Duration? get end => endMs != null ? Duration(milliseconds: endMs!) : null;
}

class IntroDbResponse {
  final int tmdbId;
  final String type;
  final List<IntroDbTimestamp> intro;
  final List<IntroDbTimestamp> recap;
  final List<IntroDbTimestamp> credits;
  final List<IntroDbTimestamp> preview;

  IntroDbResponse({
    required this.tmdbId,
    required this.type,
    required this.intro,
    required this.recap,
    required this.credits,
    required this.preview,
  });

  factory IntroDbResponse.fromEngineJson(Map<String, dynamic> json) {
    List<IntroDbTimestamp> segments(String key) {
      final raw = json[key] as List<dynamic>? ?? [];
      return raw
          .map((e) => IntroDbTimestamp.fromEngineJson(e as Map<String, dynamic>))
          .toList();
    }

    return IntroDbResponse(
      tmdbId: (json['tmdb_id'] as num?)?.toInt() ?? 0,
      type: json['kind'] as String? ?? json['type'] as String? ?? '',
      intro: segments('intro'),
      recap: segments('recap'),
      credits: segments('credits'),
      preview: segments('preview'),
    );
  }

  bool get hasAnySegments =>
      intro.isNotEmpty ||
      recap.isNotEmpty ||
      credits.isNotEmpty ||
      preview.isNotEmpty;
}

class IntroDbService {
  Future<IntroDbResponse?> getTimestamps({
    required int tmdbId,
    int? season,
    int? episode,
    String? imdbId,
  }) async {
    try {
      final decoded = await metadataRequest({
        'action': 'introdb_timestamps',
        'tmdb_id': tmdbId,
        if (season != null) 'season': season,
        if (episode != null) 'episode': episode,
        if (imdbId != null) 'imdb_id': imdbId,
      });
      final data = decoded['data'];
      if (data == null) return null;
      return IntroDbResponse.fromEngineJson(data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
