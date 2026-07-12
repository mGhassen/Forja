import 'package:forja/shared/playback/playback_engine.dart';
import 'package:forja/shared/playback/playback_service.dart';
import 'package:rust/rust.dart';

/// Player-side helpers for Source Engine Auto / pinned resolve.
abstract final class PlayerSourceResolve {
  static SourceDomain domainFor(Movie? movie) =>
      SourceDomain.fromMediaType(movie?.mediaType);

  /// Remaining providers after [currentProviderId] in domain Auto order.
  static List<String> failoverChain({
    required Movie? movie,
    required Map<String, dynamic> providers,
    String? currentProviderId,
    List<String> settingsOrder = const [],
  }) =>
      SourceEngine.nextProviderIds(
        domain: domainFor(movie),
        candidateIds: providers.keys,
        currentId: currentProviderId,
        settingsOrder: settingsOrder,
      );

  static Future<PlaybackResolveHit?> resolvePinned({
    required Movie movie,
    required Map<String, dynamic> providers,
    required String providerId,
    required int season,
    required int episode,
    bool Function()? isCancelled,
  }) =>
      PlaybackService.resolveWebstreaming(
        movie: movie,
        providers: providers,
        preferredProvider: providerId,
        season: season,
        episode: episode,
        isCancelled: isCancelled,
      );

  static Future<PlaybackResolveHit?> resolveAuto({
    required Movie movie,
    required Map<String, dynamic> providers,
    required int season,
    required int episode,
    bool Function()? isCancelled,
    void Function(List<PlaybackResolveHit> hits)? onHitsUpdated,
  }) =>
      PlaybackService.resolveWebstreaming(
        movie: movie,
        providers: providers,
        preferredProvider: SourceEngine.auto,
        season: season,
        episode: episode,
        isCancelled: isCancelled,
        onHitsUpdated: onHitsUpdated,
      );
}
