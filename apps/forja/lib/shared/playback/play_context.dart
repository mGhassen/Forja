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
    this.seasonLabel,
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

  /// Pack franchise chip label (`Season 2`, `OVA 1`, `Special 1`) for UI codes.
  final String? seasonLabel;
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
String? playbackLoadingEpisodeSubtitle({
  int? season,
  int? episode,
  String? seasonLabel,
}) {
  if (episode == null) return null;
  final label = (seasonLabel ?? '').trim();
  if (label.isNotEmpty) return '$label · Episode $episode';
  if (season != null) return 'Season $season · Episode $episode';
  return 'Episode $episode';
}

final _seasonLabelCode = RegExp(
  r'^(?:(OVA)|(Special)|Season)\s*(\d+)\b',
  caseSensitive: false,
);

/// Pack chip → Sources code prefix: `S02` / `OVA01` / `SPECIAL01`.
String? sourcesSeasonCodeFromLabel(String? seasonLabel) {
  final label = (seasonLabel ?? '').trim();
  if (label.isEmpty) return null;
  final m = _seasonLabelCode.firstMatch(label);
  if (m == null) return null;
  final n = (int.tryParse(m.group(3) ?? '') ?? 0).clamp(1, 99);
  final nn = n.toString().padLeft(2, '0');
  if (m.group(1) != null) return 'OVA$nn';
  if (m.group(2) != null) return 'SPECIAL$nn';
  return 'S$nn';
}

/// Sources footer / chrome: `S02E01`, `OVA01E01`, `SPECIAL01E01`.
String? sourcesEpisodeLabel({
  required String mediaType,
  int? season,
  int? episode,
  String? seasonLabel,
}) {
  if (mediaType != 'tv') return null;
  final e = (episode ?? 1).toString().padLeft(2, '0');
  final fromLabel = sourcesSeasonCodeFromLabel(seasonLabel);
  if (fromLabel != null) return '${fromLabel}E$e';
  final s = (season ?? 1).toString().padLeft(2, '0');
  return 'S${s}E$e';
}
