import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja/shared/player/controls/episodes/catalog_episode.dart';
import 'package:rust/rust.dart';

/// Play args shared by kit details green Play and Sources panel.
class PlayContext {
  const PlayContext({
    required this.movie,
    this.pluginId,
    this.metaItem,
    this.metaOpen,
    this.season,
    this.episode,
    this.labelSeason,
    this.malId,
    this.episodeVideoIdByNumber = const {},
    this.audioCategory,
    this.kitEpisodes,
    this.selectedPluginIds,
    this.startPosition,
    this.preferredPluginId,
    this.savedStreamUrl,
    this.loadingSubtitle,
  });

  final Movie movie;
  final String? pluginId;
  final MetaItem? metaItem;
  final MetaOpen? metaOpen;

  /// Season for extract / progress (media-local; anime franchise cours stay 1).
  final int? season;
  final int? episode;

  /// Franchise / UI season for badges when it differs from [season].
  final int? labelSeason;
  final int? malId;
  final Map<int, String> episodeVideoIdByNumber;
  final String? audioCategory;
  final List<PlayerKitEpisode>? kitEpisodes;
  final Set<String>? selectedPluginIds;
  final Duration? startPosition;
  final String? preferredPluginId;
  final String? savedStreamUrl;
  final String? loadingSubtitle;

  MetaOpen? get effectiveOpen => metaOpen ?? metaItem?.open;
}

/// Loading-overlay episode line: season + episode when both known.
String? playbackLoadingEpisodeSubtitle({int? season, int? episode}) {
  if (episode == null) return null;
  if (season != null) return 'Season $season · Episode $episode';
  return 'Episode $episode';
}

/// Sources footer / chrome: `S02E01`. Uses [labelSeason] when set (franchise UI).
String? sourcesEpisodeLabel({
  required String mediaType,
  int? season,
  int? episode,
  int? labelSeason,
}) {
  if (mediaType != 'tv') return null;
  final s = (labelSeason ?? season ?? 1).toString().padLeft(2, '0');
  final e = (episode ?? 1).toString().padLeft(2, '0');
  return 'S${s}E$e';
}
