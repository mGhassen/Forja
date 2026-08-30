import 'package:forja/shared/catalog/hub_cover_urls.dart';
import 'package:rust/rust.dart';

/// KissKH CDN URLs and TMDB `/path.jpg` keys → loadable image URL.
String? resolveHubEpisodeArtUrl(String? raw, {bool still = false}) {
  final value = raw?.trim();
  if (value == null || value.isEmpty || value == 'null') return null;
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return normalizeHubCoverUrl(value);
  }
  if (value.startsWith('/')) {
    return still ? TmdbApi.getStillUrl(value) : TmdbApi.getImageUrl(value);
  }
  return resolveHubCoverUrl(value);
}

/// Flat episode list for hub players (anime, Asian drama) - no TMDB seasons.
class PlayerHubEpisode {
  final num number;
  final String title;
  final String? overview;
  final String? thumbnailUrl;
  final int runtimeMinutes;
  final int positionMs;
  final int durationMs;
  final String? airDateLabel;
  final bool notShippedYet;

  const PlayerHubEpisode({
    required this.number,
    required this.title,
    this.overview,
    this.thumbnailUrl,
    this.runtimeMinutes = 0,
    this.positionMs = 0,
    this.durationMs = 0,
    this.airDateLabel,
    this.notShippedYet = false,
  });

  String get displayNumber =>
      number == number.truncateToDouble() ? '${number.toInt()}' : '$number';
}
