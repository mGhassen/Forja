import 'package:flutter/foundation.dart';
import 'package:forja/shared/player/controls/player_stream_menu.dart';
import 'package:forja/shared/widgets/stream_provider_probe.dart';
import 'package:rust/rust.dart';

/// Applies provider reliability scoring from CHECKING SOURCES probe updates.
///
/// Server and stream verdicts are **linked**:
/// - extract empty / failed → server −2 only
/// - extract OK + streams OK → +2 +2 (committed together when streams resolve)
/// - extract OK + all streams dead → +2 −2 (committed together)
/// - Cancel / mid-check / extract OK but streams not finished → nothing yet
abstract final class ProviderScoreProbeSync {
  /// Last applied score action per title/provider.
  static final Map<String, String> _lastApplied = {};

  static String _key(ProviderScoreScope scope, String providerId) =>
      scope.memoryKey(ProviderScoreMemory.normalizeProviderId(providerId));

  static String _actionFor({
    required StreamProviderProbeStatus status,
    required bool hasSources,
    required bool streamsResolved,
  }) {
    return switch (status) {
      // Finished check: extract OK + stream OK → linked +2+2.
      StreamProviderProbeStatus.success
          when hasSources && streamsResolved =>
        'linked_up',
      // Extract finished with streams; wait for CDN / player stream probe.
      StreamProviderProbeStatus.success when hasSources => 'await_streams',
      StreamProviderProbeStatus.success => 'down',
      // Finished check: extract OK + all streams/CDN dead → linked +2−2.
      StreamProviderProbeStatus.failed
          when hasSources && streamsResolved =>
        'linked_down',
      // Abandoned mid-check (sources listed, stream outcome never finished).
      StreamProviderProbeStatus.failed when hasSources => 'skip',
      StreamProviderProbeStatus.failed => 'down',
      StreamProviderProbeStatus.trying => 'trying',
      StreamProviderProbeStatus.pending => 'pending',
      StreamProviderProbeStatus.skippedOnTv => 'skipped',
    };
  }

  static Future<void> onProbeStatusChanged({
    required ProviderScoreScope? scope,
    required String providerId,
    required StreamProviderProbeStatus status,
    bool hasSources = false,
    /// When true, the stream/CDN check finished (anime after `_playableHits`).
    bool streamsResolved = false,
  }) async {
    if (scope == null || providerId.isEmpty) return;
    final key = _key(scope, providerId);
    final action = _actionFor(
      status: status,
      hasSources: hasSources,
      streamsResolved: streamsResolved,
    );
    if (_lastApplied[key] == action) return;
    _lastApplied[key] = action;

    switch (action) {
      case 'linked_up':
        await ProviderScoreMemory.recordLinkedStreamsUp(scope, providerId);
      case 'linked_down':
        await ProviderScoreMemory.recordLinkedStreamsDown(scope, providerId);
      case 'down':
        await ProviderScoreMemory.recordServerFailure(scope, providerId);
      default:
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

  /// Extract-only cache sync does **not** score — server/stream commit together
  /// when stream play/probe finishes (or via [streamsResolved] for anime).
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

  /// Call after linked stream scoring so probe sync does not double-apply.
  static void markScoredServerUp(ProviderScoreScope? scope, String providerId) {
    if (scope == null || providerId.isEmpty) return;
    _lastApplied[_key(scope, providerId)] = 'linked_up';
  }

  static void markScoredServerFail(
    ProviderScoreScope? scope,
    String providerId,
  ) {
    if (scope == null || providerId.isEmpty) return;
    _lastApplied[_key(scope, providerId)] = 'down';
  }

  static void markScoredLinkedDown(
    ProviderScoreScope? scope,
    String providerId,
  ) {
    if (scope == null || providerId.isEmpty) return;
    _lastApplied[_key(scope, providerId)] = 'linked_down';
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

  /// Reset in-session probe→score mapping (after user clears reliability).
  static void clearSession() => _lastApplied.clear();

  @visibleForTesting
  static void resetForTest() => _lastApplied.clear();
}
