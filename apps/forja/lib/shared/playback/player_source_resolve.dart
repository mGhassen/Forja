import 'package:forja/shared/playback/playback_engine.dart';
import 'package:rust/rust.dart';

/// Legacy player resolve shim — VOD uses Forja engine providers only.
abstract final class PlayerSourceResolve {
  static SourceDomain domainFor(Movie? movie) =>
      SourceDomain.fromMediaType(movie?.mediaType);

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

  static Future<List<String>> failoverChainForMovieAsync({
    required Movie? movie,
    required Map<String, dynamic> providers,
    String? currentProviderId,
  }) async =>
      failoverChainForMovie(
        movie: movie,
        providers: providers,
        currentProviderId: currentProviderId,
        settingsOrder: await _movieSettingsOrder(movie),
      );

  static Future<PlaybackResolveHit?> resolvePinnedForMovie({
    required Movie movie,
    required Map<String, dynamic> providers,
    required String providerId,
    required int season,
    required int episode,
    List<String> settingsOrder = const [],
    bool Function()? isCancelled,
    bool bypassDiskCache = false,
  }) async =>
      null;

  static Future<PlaybackResolveHit?> resolveAutoForMovie({
    required Movie movie,
    required Map<String, dynamic> providers,
    required int season,
    required int episode,
    List<String> settingsOrder = const [],
    bool Function()? isCancelled,
    void Function(List<PlaybackResolveHit> hits)? onHitsUpdated,
    void Function(String providerId, String status)? onProgress,
    bool? fillBackgroundHits,
  }) async =>
      null;

  static Future<List<String>> _movieSettingsOrder(Movie? movie) async {
    if (movie == null) return const [];
    final settings = SettingsService();
    final t = movie.mediaType.toLowerCase();
    if (t == 'asian_drama' || t == 'asian' || t == 'drama') {
      return settings.getEnabledAsianDramaProviderOrder();
    }
    if (t == 'anime') {
      return settings.getEnabledAnimeProviderOrder();
    }
    return settings.getEnabledStreamProviderOrder();
  }
}
