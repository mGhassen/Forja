import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';
import 'package:rust/rust.dart';

/// Play args shared by hub details green Play and Sources panel.
class HubPlayContext {
  const HubPlayContext({
    required this.movie,
    required this.engineCategory,
    this.pluginId,
    this.catalogMeta,
    this.season,
    this.episode,
    this.anilistId,
    this.malId,
    this.kisskhId,
    this.kisskhEpisodeId,
    this.kisskhEpisodeIdByNumber = const {},
    this.arabicVideoId,
    this.arabicVideoIdByEpisode = const {},
    this.animeAudioCategory,
    this.hubEpisodes,
    this.selectedPluginIds,
    this.startPosition,
    this.preferredPluginId,
    this.savedStreamUrl,
    this.loadingSubtitle,
  });

  final Movie movie;
  final String engineCategory;
  final String? pluginId;
  final CatalogMetaItem? catalogMeta;
  final int? season;
  final int? episode;
  final int? anilistId;
  final int? malId;
  final int? kisskhId;
  final int? kisskhEpisodeId;
  final Map<int, int> kisskhEpisodeIdByNumber;
  final String? arabicVideoId;
  final Map<int, String> arabicVideoIdByEpisode;
  final String? animeAudioCategory;
  final List<PlayerHubEpisode>? hubEpisodes;
  final Set<String>? selectedPluginIds;
  final Duration? startPosition;
  final String? preferredPluginId;
  final String? savedStreamUrl;
  final String? loadingSubtitle;
}
