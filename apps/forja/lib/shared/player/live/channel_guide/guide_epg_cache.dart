import 'package:forja/shared/engine/portals/network/iptv_network.dart';
import 'package:forja/shared/engine/portals/models.dart';
import 'package:forja/shared/player/live/channel_guide/channel_guide_host.dart';

/// Memoized short-EPG fetches for the in-player channel guide.
class GuideEpgCache {
  GuideEpgCache(this.portal);

  final VerifiedPortal portal;
  final Map<String, Future<List<EpgEntry>>> _cache = {};

  Future<List<EpgEntry>> load(
    IptvStream stream, {
    int limit = IptvClient.shortEpgLimit,
  }) {
    final streamId = stream.streamId;
    final epgId = stream.epgChannelId;
    if (streamId.isEmpty && epgId.isEmpty) {
      return Future.value(const []);
    }
    final key = '${streamId.isEmpty ? epgId : streamId}:$epgId:$limit';
    return rememberIptvEpg(
      _cache,
      key,
      () => IptvClient.shortEpgForStream(
        portal.portal,
        streamId: streamId,
        epgChannelId: epgId,
        limit: limit,
      ),
    );
  }

  /// Foundation paint DTO — maps portal [EpgEntry] rows.
  Future<List<GuideEpgProgramme>> loadProgrammes(
    IptvStream stream, {
    int limit = IptvClient.shortEpgLimit,
  }) async {
    final entries = await load(stream, limit: limit);
    return [
      for (final e in entries) guideEpgProgrammeFromEntry(e),
    ];
  }

  void clear() => _cache.clear();
}

/// Temporary alias while call sites migrate.
typedef IptvGuideEpgCache = GuideEpgCache;
