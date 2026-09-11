import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja/shared/player/controls/episodes/player_kit_episode.dart';
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
  final int? season;
  final int? episode;
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
