import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/playback/engine_catalog_stream_probe.dart';
import 'package:forja/shared/playback/playback_engine.dart';
import 'package:forja/shared/playback/player_stream_extract_cache.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:rust/rust.dart';

/// Player-side helpers for Source Engine Auto / pinned resolve.
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

  static Future<PlaybackResolveHit?> resolvePinnedForMovie({
    required Movie movie,
    required Map<String, dynamic> providers,
    required String providerId,
    required int season,
    required int episode,
    List<String> settingsOrder = const [],
    bool Function()? isCancelled,
    bool bypassDiskCache = false,
  }) async {
    final cacheKey = PlayerStreamExtractCache.cacheKeyFromProgress(
      tmdbId: movie.id,
      mediaType: movie.mediaType,
      season: season,
      episode: episode,
    );
    if (bypassDiskCache) {
      await PlayerStreamExtractCache.drop(cacheKey);
    } else {
      final cached = await PlayerStreamExtractCache.readLive(
        cacheKey,
        probe: probeStreamSourceUrl,
      );
      if (cached != null &&
          cached.sources.isNotEmpty &&
          cached.providerId == providerId) {
        final rank = providers.keys.toList().indexOf(cached.providerId);
        final sources = await PlaybackSelection.rankLegacySources(
          sources: cached.sources,
          providerId:
              cached.providerId.isNotEmpty ? cached.providerId : providerId,
          providerRank: rank >= 0 ? rank : 0,
        );
        final first = sources.first;
        return PlaybackResolveHit(
          providerId:
              cached.providerId.isNotEmpty ? cached.providerId : providerId,
          providerRank: rank >= 0 ? rank : 0,
          streamUrl: first.url,
          headers: first.headers,
          sources: sources,
        );
      }
    }

    if (EngineIds.isPluginChip(providerId)) {
      return _resolveEnginePinned(
        movie: movie,
        providerId: providerId,
        season: season,
        episode: episode,
        isCancelled: isCancelled,
      );
    }

    final order = settingsOrder.isNotEmpty
        ? settingsOrder
        : await _movieSettingsOrder(movie);
    return _resolveLegacyPinned(
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
    List<String> settingsOrder = const [],
    bool Function()? isCancelled,
    void Function(List<PlaybackResolveHit> hits)? onHitsUpdated,
    void Function(String providerId, String status)? onProgress,
    bool? fillBackgroundHits,
  }) async {
    final order = settingsOrder.isNotEmpty
        ? settingsOrder
        : await _movieSettingsOrder(movie);
    return PlaybackEngine.resolveStreamingRace(
      providers: providers,
      movie: movie,
      season: season,
      episode: episode,
      settingsOrder: order,
      preferredProvider: SourceEngine.auto,
      domain: domainFor(movie),
      isCancelled: isCancelled,
      onHitsUpdated: onHitsUpdated,
      onProgress: onProgress,
      fillBackgroundHits: fillBackgroundHits ?? false,
    );
  }

  static Future<PlaybackResolveHit?> _resolveLegacyPinned({
    required Movie movie,
    required Map<String, dynamic> providers,
    required String providerId,
    required int season,
    required int episode,
    required List<String> settingsOrder,
    bool Function()? isCancelled,
  }) =>
      PlaybackEngine.resolveStreamingRace(
        providers: providers,
        movie: movie,
        season: season,
        episode: episode,
        settingsOrder: settingsOrder,
        preferredProvider: providerId,
        domain: domainFor(movie),
        isCancelled: isCancelled,
      );

  static Future<PlaybackResolveHit?> _resolveEnginePinned({
    required Movie movie,
    required String providerId,
    required int season,
    required int episode,
    bool Function()? isCancelled,
  }) async {
    final pluginId = EngineIds.pluginIdFromChip(providerId);
    if (pluginId == null) return null;
    final cancelled = isCancelled ?? (() => false);
    if (cancelled()) return null;

    final isTv = movie.mediaType.toLowerCase() == 'tv';
    final year = movie.releaseDate.length >= 4
        ? movie.releaseDate.substring(0, 4)
        : null;
    EngineExtractResult? batch;
    try {
      batch = await EngineService.instance.runPluginIsolated(
        pluginId: pluginId,
        tmdbId: movie.id > 0 ? movie.id.toString() : '0',
        type: isTv ? 'tv' : 'movie',
        season: isTv ? season : null,
        episode: isTv ? episode : null,
        title: movie.title,
        year: year,
        movie: movie,
        allowHostFallback: false,
      );
    } catch (e) {
      debugPrint('[PlayerSourceResolve] engine $pluginId failed: $e');
    }
    if (cancelled()) return null;
    if (batch == null || batch.streams.isEmpty) return null;

    final settings = SettingsService();
    final profile = PlatformPlayback.capabilities;
    final streamSources = await buildProbedEngineCatalogSources(
      profile: profile,
      settings: settings,
      rows: batch.streams,
      isAborted: cancelled,
    );
    if (streamSources.isEmpty) return null;

    final playable = rankStreamSources(
      sources: streamSources,
      providerId: providerId,
    );
    final first = streamSources.first;
    return PlaybackResolveHit(
      providerId: providerId,
      providerRank: 0,
      streamUrl: first.url,
      headers: first.headers,
      sources: playable,
    );
  }

  static Future<List<String>> _movieSettingsOrder(Movie movie) async {
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
