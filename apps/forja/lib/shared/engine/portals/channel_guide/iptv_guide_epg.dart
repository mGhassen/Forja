import 'package:forja/shared/engine/portals/network/iptv_network.dart';
import 'package:forja/shared/engine/portals/models.dart';

/// Memoized short-EPG fetches for the in-player channel guide.
class IptvGuideEpgCache {
  IptvGuideEpgCache(this.portal);

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

  void clear() => _cache.clear();
}
