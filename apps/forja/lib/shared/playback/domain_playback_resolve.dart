import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forja/features/anime/catalog/anime_service.dart';
import 'package:forja/features/asian_drama/catalog/kisskh_extractor.dart';
import 'package:forja/shared/playback/playback_engine.dart';
import 'package:forja/shared/playback/stream_provider_resolver.dart';
import 'package:rust/rust.dart';

/// Domain-neutral playback resolve — shared by movies, anime, and Asian drama.
abstract final class DomainPlaybackResolve {
  static Future<PlaybackResolveHit?> resolve({
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
    AnimeService? animeService,
    KissKhExtractor? kissKhExtractor,
  }) async {
    final order = SourceEngine.orderProviders(
      domain: domain,
      candidateIds: providers.keys,
      preferred: preferredProvider,
      settingsOrder: settingsOrder,
    );
    if (order.orderedIds.isEmpty) return null;

    final orderedProviders = <String, dynamic>{
      for (final id in order.orderedIds)
        if (providers.containsKey(id)) id: providers[id]!,
    };
    final effectiveRanks = {
      for (final row in order.rows) row.id: row.effectiveRank,
    };

    final r = resolver ??
        DomainStreamProviderResolver(
          animeService: animeService,
          kissKhExtractor: kissKhExtractor,
        );

    return PlaybackEngine.resolveStreamingRace(
      providers: orderedProviders,
      movie: movie,
      season: season,
      episode: episode,
      resolver: r,
      isCancelled: isCancelled,
      onProgress: onProgress,
      onHitsUpdated: onHitsUpdated,
      maxInFlight: maxInFlight ?? PlaybackEngine.playStartMaxInFlight,
      fillBackgroundHits: fillBackgroundHits,
      effectiveRanks: effectiveRanks,
    );
  }

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
}

/// Extends movie resolver with anime embed + KissKH branches.
class DomainStreamProviderResolver extends StreamProviderResolver {
  DomainStreamProviderResolver({
    super.extractor,
    AnimeService? animeService,
    KissKhExtractor? kissKhExtractor,
  })  : _animeService = animeService ?? AnimeService(),
        _kissKhExtractor = kissKhExtractor ?? KissKhExtractor();

  final AnimeService _animeService;
  final KissKhExtractor _kissKhExtractor;

  @override
  Future<StreamProviderResolveResult?> resolve({
    required String key,
    required Movie movie,
    required int season,
    required int episode,
    required Map<String, dynamic> providers,
    bool Function()? isCancelled,
  }) async {
    final cancelled = isCancelled ?? (() => false);
    final payload = providers[key];

    if (payload is AnimeEmbed) {
      return _resolveAnimeEmbed(payload, cancelled);
    }

    if (key == 'kisskh' && payload is Map<String, dynamic>) {
      return _resolveKissKh(payload, cancelled);
    }

    return super.resolve(
      key: key,
      movie: movie,
      season: season,
      episode: episode,
      providers: providers,
      isCancelled: isCancelled,
    );
  }

  Future<StreamProviderResolveResult?> _resolveAnimeEmbed(
    AnimeEmbed embed,
    bool Function() cancelled,
  ) async {
    try {
      final candidates = await _animeService.extractDirectCandidates(embed);
      if (cancelled() || candidates.isEmpty) return null;
      final sources = <StreamSource>[];
      String? primaryUrl;
      Map<String, String>? primaryHeaders;
      final subtitles = <Map<String, dynamic>>[];
      for (final direct in candidates) {
        if (direct.url.isEmpty) continue;
        final headers = <String, String>{
          'Referer': direct.referer,
          'Origin': direct.origin,
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        };
        final title = (direct.streamLabel?.isNotEmpty == true)
            ? direct.streamLabel!
            : embed.displayName;
        primaryUrl ??= direct.url;
        primaryHeaders ??= headers;
        sources.add(StreamSource(
          url: direct.url,
          title: title,
          type: direct.url.contains('.m3u8') ? 'hls' : 'video',
          headers: headers,
        ));
        for (final track in direct.tracks) {
          subtitles.add({
            'url': track.url,
            'display': track.label,
            'language': track.label,
            'referer': direct.referer,
            'origin': direct.origin,
          });
        }
      }
      if (primaryUrl == null || primaryUrl.isEmpty) return null;
      return StreamProviderResolveResult(
        streamUrl: primaryUrl,
        headers: primaryHeaders,
        sources: sources,
        subtitles: subtitles.isEmpty ? null : subtitles,
      );
    } catch (e, st) {
      debugPrint('[DomainStreamProviderResolver] anime ${embed.displayName}: $e\n$st');
      return null;
    }
  }

  Future<StreamProviderResolveResult?> _resolveKissKh(
    Map<String, dynamic> ctx,
    bool Function() cancelled,
  ) async {
    try {
      final stream = await _kissKhExtractor.resolve(
        dramaId: (ctx['dramaId'] as num).toInt(),
        dramaTitle: ctx['dramaTitle']?.toString() ?? '',
        episodeId: (ctx['episodeId'] as num).toInt(),
        episodeNumber: (ctx['episodeNumber'] as num).toDouble(),
        isCancelled: () => cancelled(),
        onProgress: (_, _) {},
      );
      if (cancelled() || stream == null) return null;
      final sources = stream.toSources(label: 'kisskh');
      return StreamProviderResolveResult(
        streamUrl: sources.first.url,
        headers: sources.first.headers,
        sources: sources,
        subtitles: stream.subtitles,
      );
    } catch (e, st) {
      debugPrint('[DomainStreamProviderResolver] kisskh failed: $e\n$st');
      return null;
    }
  }

  @override
  void cancelPending() {
    super.cancelPending();
    unawaited(_kissKhExtractor.cancel());
  }
}
