import 'package:forja/shared/engine/portals/guide/channel_guides.dart';
import 'package:forja/shared/engine/portals/models.dart';
import 'package:forja/shared/engine/portals/network/portal_network.dart';

/// Memoized short-EPG fetches for portal-backed guide paint.
class GuideEpgCache {
  GuideEpgCache(this.portal);

  final VerifiedPortal portal;
  final Map<String, Future<List<EpgEntry>>> _cache = {};

  Future<List<EpgEntry>> load(
    PortalStream stream, {
    int limit = PortalClient.shortEpgLimit,
  }) {
    final streamId = stream.streamId;
    final epgId = stream.epgChannelId;
    if (streamId.isEmpty && epgId.isEmpty) {
      return Future.value(const []);
    }
    final key = '${streamId.isEmpty ? epgId : streamId}:$epgId:$limit';
    return rememberPortalEpg(
      _cache,
      key,
      () => PortalClient.shortEpgForStream(
        portal.portal,
        streamId: streamId,
        epgChannelId: epgId,
        limit: limit,
      ),
    );
  }

  /// Foundation paint DTO — maps portal [EpgEntry] rows.
  Future<List<GuideEpgProgramme>> loadProgrammes(
    PortalStream stream, {
    int limit = PortalClient.shortEpgLimit,
  }) async {
    final entries = await load(stream, limit: limit);
    return [
      for (final e in entries) guideEpgProgrammeFromEntry(e),
    ];
  }

  void clear() => _cache.clear();
}
