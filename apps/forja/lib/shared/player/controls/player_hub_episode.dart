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
