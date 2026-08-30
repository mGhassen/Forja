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
    this.catalogOpen,
    this.season,
    this.episode,
    this.malId,
    this.episodeVideoIdByNumber = const {},
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
  final CatalogOpen? catalogOpen;
  final int? season;
  final int? episode;
  final int? malId;
  final Map<int, String> episodeVideoIdByNumber;
  final String? animeAudioCategory;
  final List<PlayerHubEpisode>? hubEpisodes;
  final Set<String>? selectedPluginIds;
  final Duration? startPosition;
  final String? preferredPluginId;
  final String? savedStreamUrl;
  final String? loadingSubtitle;

  CatalogOpen? get effectiveOpen => catalogOpen ?? catalogMeta?.open;
}
