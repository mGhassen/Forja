import 'package:flutter/foundation.dart';
import 'package:forja/shared/player/controls/player_stream_menu.dart';
import 'package:forja/shared/widgets/stream_provider_probe.dart';
import 'package:rust/rust.dart';

/// Applies provider reliability scoring from CHECKING SOURCES probe updates.
abstract final class ProviderScoreProbeSync {
  static final Map<String, StreamProviderProbeStatus> _lastStatus = {};

  static String _key(ProviderScoreScope scope, String providerId) =>
      scope.memoryKey(ProviderScoreMemory.normalizeProviderId(providerId));

  /// Drives only the **server** verdict: a provider that already extracted
  /// streams resolved successfully (server up), even if those streams later
  /// prove dead — stream health is scored separately by the player probe.
  static StreamProviderProbeStatus effectiveStatus({
    required StreamProviderProbeStatus status,
    required bool hasSources,
  }) {
    if (hasSources) {
      if (status == StreamProviderProbeStatus.failed ||
          status == StreamProviderProbeStatus.trying ||
          status == StreamProviderProbeStatus.pending) {
        return StreamProviderProbeStatus.success;
      }
    }
    return status;
  }

  static Future<void> onProbeStatusChanged({
    required ProviderScoreScope? scope,
    required String providerId,
    required StreamProviderProbeStatus status,
    bool hasSources = false,
  }) async {
    if (scope == null || providerId.isEmpty) return;
    final resolved =
        effectiveStatus(status: status, hasSources: hasSources);
    final key = _key(scope, providerId);
    final prev = _lastStatus[key];
    if (prev == resolved) return;
    _lastStatus[key] = resolved;

    switch (resolved) {
      case StreamProviderProbeStatus.success:
        await ProviderScoreMemory.recordServerUp(scope, providerId);
      case StreamProviderProbeStatus.failed:
        await ProviderScoreMemory.recordServerFailure(scope, providerId);
      case StreamProviderProbeStatus.trying:
      case StreamProviderProbeStatus.pending:
        break;
    }
  }

  static Future<void> syncProbeList({
    required ProviderScoreScope? scope,
    required List<StreamProviderProbe> probes,
    Map<String, List<StreamSource>>? sourcesByProvider,
  }) async {
    for (final probe in probes) {
      final sources = sourcesByProvider?[probe.id];
      final hasSources = sources != null && sources.isNotEmpty;
      await onProbeStatusChanged(
        scope: scope,
        providerId: probe.id,
        status: probe.status,
        hasSources: hasSources,
      );
    }
  }

  /// Mark every provider that already has extracted streams as server-up.
  static Future<void> syncSourcesCache({
    required ProviderScoreScope? scope,
    required Map<String, List<StreamSource>> sourcesByProvider,
  }) async {
    if (scope == null) return;
    for (final entry in sourcesByProvider.entries) {
      if (entry.value.isEmpty) continue;
      await onProbeStatusChanged(
        scope: scope,
        providerId: entry.key,
        status: StreamProviderProbeStatus.success,
        hasSources: true,
      );
    }
  }

  /// Call after manual server scoring so probe sync does not double-apply.
  static void markScoredServerUp(ProviderScoreScope? scope, String providerId) {
    if (scope == null || providerId.isEmpty) return;
    _lastStatus[_key(scope, providerId)] =
        StreamProviderProbeStatus.success;
  }

  static void markScoredServerFail(
    ProviderScoreScope? scope,
    String providerId,
  ) {
    if (scope == null || providerId.isEmpty) return;
    _lastStatus[_key(scope, providerId)] = StreamProviderProbeStatus.failed;
  }

  static ProviderScoreScope? scopeFromPlayer({
    Movie? movie,
    Map<String, dynamic>? providers,
    int? selectedSeason,
    int? selectedEpisode,
    num? hubEpisodeNumber,
    String? activeProvider,
  }) =>
      PlayerStreamMenu.scoreScope(
        movie: movie,
        providers: providers,
        selectedSeason: selectedSeason,
        selectedEpisode: selectedEpisode,
        hubEpisodeNumber: hubEpisodeNumber,
        activeProvider: activeProvider,
      );

  @visibleForTesting
  static void resetForTest() => _lastStatus.clear();
}
