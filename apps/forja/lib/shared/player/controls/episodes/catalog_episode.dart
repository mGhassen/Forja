import 'package:forja_foundation/utils/cover_urls.dart';

/// Absolute cover URLs only (pack must ship https). Relative paths stay as-is.
String? resolveEpisodeArtUrl(String? raw, {bool still = false}) {
  final value = raw?.trim();
  if (value == null || value.isEmpty || value == 'null') return null;
  return normalizeCoverUrl(value);
}

/// Flat episode list for hub players (anime, Asian drama) - no TMDB seasons.
class PlayerKitEpisode {
  final num number;
  final String title;
  final String? overview;
  final String? thumbnailUrl;
  final int runtimeMinutes;
  final int positionMs;
  final int durationMs;
  final String? airDateLabel;
  final bool notShippedYet;

  const PlayerKitEpisode({
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
