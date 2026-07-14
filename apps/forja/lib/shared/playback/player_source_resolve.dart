import 'package:forja/shared/playback/playback_engine.dart';
import 'package:forja/shared/playback/playback_service.dart';
import 'package:forja/shared/playback/webstreaming_stream_cache.dart';
import 'package:rust/rust.dart';

/// Player-side helpers for Source Engine Auto / pinned resolve.
abstract final class PlayerSourceResolve {
  static SourceDomain domainFor(Movie? movie) =>
      SourceDomain.fromMediaType(movie?.mediaType);

  /// Remaining providers after [currentProviderId] in domain Auto order.
  static List<String> failoverChain({
    required SourceDomain domain,
    required Map<String, dynamic> providers,
    String? currentProviderId,
    List<String> settingsOrder = const [],
  }) =>
      SourceEngine.nextProviderIds(
        domain: domain,
        candidateIds: providers.keys,
        currentId: currentProviderId,
        settingsOrder: settingsOrder,
      );

  /// Movie/series helper — infers domain from [movie].
  static List<String> failoverChainForMovie({
    required Movie? movie,
    required Map<String, dynamic> providers,
    String? currentProviderId,
    List<String> settingsOrder = const [],
  }) =>
      failoverChain(
        domain: domainFor(movie),
        providers: providers,
        currentProviderId: currentProviderId,
        settingsOrder: settingsOrder,
      );

  static Future<PlaybackResolveHit?> resolvePinned({
    required SourceDomain domain,
    required Movie movie,
    required Map<String, dynamic> providers,
    required String providerId,
    required int season,
    required int episode,
    List<String> settingsOrder = const [],
    bool Function()? isCancelled,
  }) =>
      PlaybackService.resolveDomain(
        domain: domain,
        movie: movie,
        providers: providers,
        preferredProvider: providerId,
        season: season,
        episode: episode,
        settingsOrder: settingsOrder,
        isCancelled: isCancelled,
      );

  static Future<PlaybackResolveHit?> resolveAuto({
    required SourceDomain domain,
    required Movie movie,
    required Map<String, dynamic> providers,
    required int season,
    required int episode,
    List<String> settingsOrder = const [],
    bool Function()? isCancelled,
    void Function(List<PlaybackResolveHit> hits)? onHitsUpdated,
    void Function(String providerId, String status)? onProgress,
  }) =>
      PlaybackService.resolveDomain(
        domain: domain,
        movie: movie,
        providers: providers,
        preferredProvider: SourceEngine.auto,
        season: season,
        episode: episode,
        settingsOrder: settingsOrder,
        isCancelled: isCancelled,
        onHitsUpdated: onHitsUpdated,
        onProgress: onProgress,
      );

  static Future<List<String>> _movieSettingsOrder(Movie movie) async {
    final settings = SettingsService();
    return movie.mediaType == 'tv' || movie.mediaType == 'series'
        ? settings.getStreamProviderOrder()
        : settings.getStreamProviderOrder();
  }

  static Future<PlaybackResolveHit?> resolvePinnedForMovie({
    required Movie movie,
    required Map<String, dynamic> providers,
    required String providerId,
    required int season,
    required int episode,
    bool Function()? isCancelled,
  }) async {
    final cacheKey = WebstreamingStreamCache.cacheKeyFromProgress(
      tmdbId: movie.id,
      mediaType: movie.mediaType,
      season: season,
      episode: episode,
    );
    final cached = await WebstreamingStreamCache.read(cacheKey);
    // Only reuse cache when it is for this exact provider. A different
    // server's extract must resolve fresh.
    if (cached != null &&
        cached.sources.isNotEmpty &&
        cached.providerId == providerId) {
      final rank = providers.keys.toList().indexOf(cached.providerId);
      final sources = await PlaybackSelection.rankLegacySources(
        sources: cached.sources,
        providerId: cached.providerId.isNotEmpty ? cached.providerId : providerId,
        providerRank: rank >= 0 ? rank : 0,
      );
      final first = sources.first;
      return PlaybackResolveHit(
        providerId: cached.providerId.isNotEmpty ? cached.providerId : providerId,
        providerRank: rank >= 0 ? rank : 0,
        streamUrl: first.url,
        headers: first.headers,
        sources: sources,
      );
    }

    final order = await _movieSettingsOrder(movie);
    return resolvePinned(
      domain: domainFor(movie),
      movie: movie,
      providers: providers,
      providerId: providerId,
      season: season,
      episode: episode,
      settingsOrder: order,
      isCancelled: isCancelled,
    );
  }

  static Future<PlaybackResolveHit?> resolveAutoForMovie({
    required Movie movie,
    required Map<String, dynamic> providers,
    required int season,
    required int episode,
    bool Function()? isCancelled,
    void Function(List<PlaybackResolveHit> hits)? onHitsUpdated,
    void Function(String providerId, String status)? onProgress,
  }) async {
    final order = await _movieSettingsOrder(movie);
    return resolveAuto(
      domain: domainFor(movie),
      movie: movie,
      providers: providers,
      season: season,
      episode: episode,
      settingsOrder: order,
      isCancelled: isCancelled,
      onHitsUpdated: onHitsUpdated,
      onProgress: onProgress,
    );
  }

  static Future<List<String>> failoverChainForMovieAsync({
    required Movie? movie,
    required Map<String, dynamic> providers,
    String? currentProviderId,
  }) async {
    if (movie == null) return const [];
    final order = await _movieSettingsOrder(movie);
    return failoverChainForMovie(
      movie: movie,
      providers: providers,
      currentProviderId: currentProviderId,
      settingsOrder: order,
    );
  }
}
