import 'package:forja/shared/catalog/catalog_details_fetch.dart';
import 'package:forja/shared/catalog/hub_cover_urls.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';

class HubDramaEpisodeCache {
  HubDramaEpisodeCache._();

  static const ttl = Duration(minutes: 30);
  static final _byMetaId = <String, ({DateTime at, List<PlayerHubEpisode> episodes})>{};

  static List<PlayerHubEpisode>? read(String metaId) {
    final hit = _byMetaId[metaId];
    if (hit == null) return null;
    if (DateTime.now().difference(hit.at) > ttl) {
      _byMetaId.remove(metaId);
      return null;
    }
    return List<PlayerHubEpisode>.from(hit.episodes);
  }

  static void write(String metaId, List<PlayerHubEpisode> episodes) {
    if (metaId.isEmpty || episodes.isEmpty) return;
    _byMetaId[metaId] = (
      at: DateTime.now(),
      episodes: List.from(episodes),
    );
  }

  static void invalidate(String metaId) => _byMetaId.remove(metaId);
}

List<PlayerHubEpisode> hubEpisodesFromCatalogMeta(CatalogMetaItem meta) {
  final cover = resolveHubCoverUrl(
    meta.background.isNotEmpty ? meta.background : meta.poster,
  );
  return [
    for (final v in meta.videos)
      _hubEpisodeRow(video: v, fallbackCover: cover),
  ];
}

PlayerHubEpisode _hubEpisodeRow({
  required CatalogVideo video,
  required String fallbackCover,
}) {
  final epNum = video.episode ?? 1;
  final thumbRaw = video.thumbnail.trim();
  final thumb = thumbRaw.isNotEmpty
      ? resolveHubEpisodeArtUrl(thumbRaw, still: true)
      : (fallbackCover.isNotEmpty ? fallbackCover : null);
  return PlayerHubEpisode(
    number: epNum,
    title: video.title.isNotEmpty ? video.title : 'Episode $epNum',
    thumbnailUrl: thumb,
  );
}

/// Keep enriched rows from details; fetch pack `details` when the list is missing.
Future<List<PlayerHubEpisode>?> ensureDramaHubEpisodes({
  required String? pluginId,
  required String? metaId,
  required List<PlayerHubEpisode>? hubEpisodes,
  int? liveEpisodeCount,
}) async {
  if (pluginId == null || metaId == null || metaId.isEmpty) return hubEpisodes;

  if (hubEpisodes != null && hubEpisodes.isNotEmpty) {
    HubDramaEpisodeCache.write(metaId, hubEpisodes);
    return hubEpisodes;
  }

  final cached = HubDramaEpisodeCache.read(metaId);
  if (cached != null && cached.isNotEmpty) {
    if (liveEpisodeCount == null || liveEpisodeCount == cached.length) {
      return cached;
    }
  }

  try {
    final meta = await fetchCatalogMetaDetails(
      pluginId: pluginId,
      metaId: metaId,
    );
    if (meta == null || meta.videos.isEmpty) return hubEpisodes ?? cached;

    final built = hubEpisodesFromCatalogMeta(meta);
    if (built.isEmpty) return hubEpisodes ?? cached;
    HubDramaEpisodeCache.write(metaId, built);
    return built;
  } catch (_) {
    return hubEpisodes ?? cached;
  }
}
