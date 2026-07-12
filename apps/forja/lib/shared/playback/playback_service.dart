import 'package:forja/shared/playback/domain_playback_resolve.dart';
import 'package:forja/shared/playback/playback_engine.dart';
import 'package:forja/shared/playback/stream_provider_resolver.dart';
import 'package:rust/rust.dart';

/// App-facing resolve API — UI asks for playable content, not providers.
///
/// Preferred:
/// - [SourceEngine.auto] → domain profiles + race
/// - concrete id → strict single-provider resolve (manual mode)
abstract final class PlaybackService {
  static Future<PlaybackResolveHit?> resolveWebstreaming({
    required Movie movie,
    required Map<String, dynamic> providers,
    required int season,
    required int episode,
    String preferredProvider = SourceEngine.auto,
    List<String> settingsOrder = const [],
    StreamProviderResolver? resolver,
    bool Function()? isCancelled,
    void Function(String providerId, String status)? onProgress,
    void Function(List<PlaybackResolveHit> hits)? onHitsUpdated,
    int? maxInFlight,
  }) async {
    final domain = SourceDomain.fromMediaType(movie.mediaType);
    return DomainPlaybackResolve.resolve(
      domain: domain,
      providers: providers,
      movie: movie,
      season: season,
      episode: episode,
      preferredProvider: preferredProvider,
      settingsOrder: settingsOrder,
      resolver: resolver,
      isCancelled: isCancelled,
      onProgress: onProgress,
      onHitsUpdated: onHitsUpdated,
      maxInFlight: maxInFlight,
      fillBackgroundHits: false,
    );
  }

  static Future<PlaybackResolveHit?> resolveDomain({
    required SourceDomain domain,
    required Map<String, dynamic> providers,
    required Movie movie,
    int season = 1,
    int episode = 1,
    String preferredProvider = SourceEngine.auto,
    List<String> settingsOrder = const [],
    StreamProviderResolver? resolver,
    bool Function()? isCancelled,
    void Function(String providerId, String status)? onProgress,
    void Function(List<PlaybackResolveHit> hits)? onHitsUpdated,
    int? maxInFlight,
    bool fillBackgroundHits = false,
  }) =>
      DomainPlaybackResolve.resolve(
        domain: domain,
        providers: providers,
        movie: movie,
        season: season,
        episode: episode,
        preferredProvider: preferredProvider,
        settingsOrder: settingsOrder,
        resolver: resolver,
        isCancelled: isCancelled,
        onProgress: onProgress,
        onHitsUpdated: onHitsUpdated,
        maxInFlight: maxInFlight,
        fillBackgroundHits: fillBackgroundHits,
      );

  /// Anime / drama: reorder candidate keys for a domain.
  static List<String> orderDomainKeys({
    required SourceDomain domain,
    required List<String> keys,
    String preferredProvider = SourceEngine.auto,
    List<String> settingsOrder = const [],
  }) =>
      SourceEngine.orderProviderIds(
        domain: domain,
        candidateIds: keys,
        preferred: preferredProvider,
        settingsOrder: settingsOrder,
      );
}
