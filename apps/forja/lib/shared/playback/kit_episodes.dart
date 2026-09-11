import 'package:forja/shared/kit/kit_details_meta.dart';
import 'package:forja/shared/kit/details_fetch.dart';
import 'package:forja/shared/kit/cover_urls.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja/shared/player/controls/episodes/player_kit_episode.dart';

class KitEpisodeCache {
  KitEpisodeCache._();

  static const ttl = Duration(minutes: 30);
  static final _byMetaId =
      <String, ({DateTime at, List<PlayerKitEpisode> episodes})>{};

  static List<PlayerKitEpisode>? read(String metaId) {
    final hit = _byMetaId[metaId];
    if (hit == null) return null;
    if (DateTime.now().difference(hit.at) > ttl) {
      _byMetaId.remove(metaId);
      return null;
    }
    return List<PlayerKitEpisode>.from(hit.episodes);
  }

  static void write(String metaId, List<PlayerKitEpisode> episodes) {
    if (metaId.isEmpty || episodes.isEmpty) return;
    _byMetaId[metaId] = (
      at: DateTime.now(),
      episodes: List.from(episodes),
    );
  }

  static void invalidate(String metaId) => _byMetaId.remove(metaId);
}

List<PlayerKitEpisode> episodesFromMeta(MetaItem meta) {
  final cover = resolveCoverUrl(
    meta.background.isNotEmpty ? meta.background : meta.poster,
  );
  return [
    for (final v in meta.videos)
      _kitEpisodeRow(video: v, fallbackCover: cover),
  ];
}

PlayerKitEpisode _kitEpisodeRow({
  required MetaVideo video,
  required String fallbackCover,
}) {
  final epNum = video.episode ?? 1;
  final thumbRaw = video.thumbnail.trim();
  final thumb = thumbRaw.isNotEmpty
      ? resolveEpisodeArtUrl(thumbRaw, still: true)
      : (fallbackCover.isNotEmpty ? fallbackCover : null);
  final air = hubVideoAirDateInfo(video);
  return PlayerKitEpisode(
    number: epNum,
    title: video.title.isNotEmpty ? video.title : 'Episode $epNum',
    thumbnailUrl: thumb,
    airDateLabel: air.label,
    notShippedYet: air.notShippedYet,
  );
}

bool _episodesNeedEnrichedDetails(List<PlayerKitEpisode> episodes) =>
    episodes.every((e) => (e.thumbnailUrl ?? '').trim().isEmpty);

/// Keep enriched rows from details; fetch pack `details` when the list is missing.
Future<List<PlayerKitEpisode>?> ensureKitEpisodes({
  required String? pluginId,
  required String? metaId,
  MetaItem? meta,
  required List<PlayerKitEpisode>? episodes,
  int? liveEpisodeCount,
}) async {
  if (pluginId == null || metaId == null || metaId.isEmpty) return episodes;

  if (episodes != null &&
      episodes.isNotEmpty &&
      !_episodesNeedEnrichedDetails(episodes)) {
    KitEpisodeCache.write(metaId, episodes);
    return episodes;
  }

  final cached = KitEpisodeCache.read(metaId);
  if (cached != null && cached.isNotEmpty) {
    if (liveEpisodeCount == null || liveEpisodeCount == cached.length) {
      return cached;
    }
  }

  try {
    final fetched = await fetchMetaDetails(
      pluginId: pluginId,
      metaId: metaId,
      seed: meta,
    );
    if (fetched == null || fetched.videos.isEmpty) {
      return episodes ?? cached;
    }

    final built = episodesFromMeta(fetched);
    if (built.isEmpty) return episodes ?? cached;
    KitEpisodeCache.write(metaId, built);
    return built;
  } catch (_) {
    return episodes ?? cached;
  }
}
