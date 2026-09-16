import 'package:forja/shared/engine/portals/guide/channel_guides.dart';
import 'package:forja/shared/engine/portals/models.dart';
import 'package:forja/shared/engine/portals/network/portal_network.dart';

/// Memoized short-EPG / guide-table fetches for portal-backed guide paint.
class GuideEpgCache {
  GuideEpgCache(this.portal);

  final VerifiedPortal portal;
  final Map<String, Future<List<EpgEntry>>> _cache = {};
  final Map<String, Future<List<EpgEntry>>> _guideCache = {};
  /// Mapped paint DTOs — same key as [load]; identity-stable for FutureBuilder.
  final Map<String, Future<List<GuideEpgProgramme>>> _programmeCache = {};

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
  ///
  /// Memoizes the mapped [Future] (not only the entry fetch) so guide hover /
  /// card rebuilds keep the same FutureBuilder identity.
  Future<List<GuideEpgProgramme>> loadProgrammes(
    PortalStream stream, {
    int limit = PortalClient.shortEpgLimit,
  }) {
    final streamId = stream.streamId;
    final epgId = stream.epgChannelId;
    if (streamId.isEmpty && epgId.isEmpty) {
      return Future.value(const []);
    }
    final key = '${streamId.isEmpty ? epgId : streamId}:$epgId:$limit';
    return _programmeCache.putIfAbsent(key, () async {
      final entries = await load(stream, limit: limit);
      return [
        for (final e in entries) guideEpgProgrammeFromEntry(e),
      ];
    });
  }

  /// Full catalog EPG window (`get_simple_data_table` / Stalker Mag).
  Future<List<GuideEpgProgramme>> loadGuideProgrammes({
    required String streamId,
    String epgChannelId = '',
    DateTime? windowStart,
    DateTime? windowEnd,
  }) {
    if (streamId.isEmpty && epgChannelId.isEmpty) {
      return Future.value(const []);
    }
    final key = '${streamId.isEmpty ? epgChannelId : streamId}:$epgChannelId';
    final future = _guideCache.putIfAbsent(key, () async {
      final window = _guideWindow(now: DateTime.now());
      final start = windowStart ?? window.start;
      final end = windowEnd ?? window.end;
      if (portal.platform == PortalPlatform.stalker) {
        return PortalClient.simpleDataTable(
          portal.portal,
          streamId,
          epgChannelId: epgChannelId,
          windowStart: start,
          windowEnd: end,
          timeout: const Duration(seconds: 8),
        );
      }
      if (streamId.isNotEmpty) {
        final rows = await PortalClient.simpleDataTable(
          portal.portal,
          streamId,
          windowStart: start,
          windowEnd: end,
        );
        if (rows.isNotEmpty) return rows;
      }
      if (epgChannelId.isNotEmpty && epgChannelId != streamId) {
        return PortalClient.simpleDataTable(
          portal.portal,
          epgChannelId,
          windowStart: start,
          windowEnd: end,
        );
      }
      return const <EpgEntry>[];
    });
    return future.then(
      (entries) => [
        for (final e in entries) guideEpgProgrammeFromEntry(e),
      ],
    );
  }

  static ({DateTime start, DateTime end}) _guideWindow({DateTime? now}) {
    final n = now ?? DateTime.now();
    final flooredMinute = n.minute >= 30 ? 30 : 0;
    final anchor = DateTime(n.year, n.month, n.day, n.hour, flooredMinute);
    final start = anchor.subtract(const Duration(hours: 6));
    final end = start.add(const Duration(hours: 30));
    return (start: start, end: end);
  }

  void clear() {
    _cache.clear();
    _guideCache.clear();
    _programmeCache.clear();
  }
}
