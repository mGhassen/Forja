import 'package:rust/rust.dart';

/// Live embed sniff stub — VOD resolve uses Forja engine providers only.
///
/// Live Matches still imports this for Android sniff timeout fallback.
class StreamExtractor {
  Future<ExtractedMedia?> extract(
    String url, {
    String? referer,
    String? iframeWrapperBaseUrl,
    Duration timeout = const Duration(seconds: 30),
    bool Function()? isCancelled,
    Object? profile,
    String? providerId,
  }) async {
    return null;
  }

  Future<ExtractedMedia?> extractWithAmri({
    required String tmdbId,
    required bool isMovie,
    int? season,
    int? episode,
    bool Function()? isCancelled,
  }) async {
    return null;
  }
}
