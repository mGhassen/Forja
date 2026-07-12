import 'package:flutter/foundation.dart';
import 'package:forja/shared/player/controls/player_stream_menu.dart';
import 'package:forja/shared/widgets/stream_provider_probe.dart';
import 'package:rust/rust.dart';

/// Applies provider reliability scoring from CHECKING SOURCES probe updates.
abstract final class ProviderScoreProbeSync {
  static final Map<String, StreamProviderProbeStatus> _lastStatus = {};

  static String _key(ProviderScoreScope scope, String providerId) =>
      scope.memoryKey(ProviderScoreMemory.normalizeProviderId(providerId));

  static Future<void> onProbeStatusChanged({
    required ProviderScoreScope? scope,
    required String providerId,
    required StreamProviderProbeStatus status,
  }) async {
    if (scope == null || providerId.isEmpty) return;
    final key = _key(scope, providerId);
    final prev = _lastStatus[key];
    if (prev == status) return;
    _lastStatus[key] = status;

    switch (status) {
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
  }) async {
    for (final probe in probes) {
      await onProbeStatusChanged(
        scope: scope,
        providerId: probe.id,
        status: probe.status,
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
