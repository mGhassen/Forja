import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forja/features/anime/catalog/anime_service.dart';
import 'package:forja/features/anime/catalog/miruro_pipe_session.dart';
import 'package:forja/features/asian_drama/catalog/kisskh_service.dart';
import 'package:forja/shared/extractors/providers/kisskh/kisskh_extractor.dart';
import 'package:forja/shared/playback/playback_engine.dart';
import 'package:forja/shared/player/player/utils.dart';
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

    final usesDomainHost = orderedProviders.values.any((v) => v is AnimeEmbed) ||
        orderedProviders.keys.any(_isKissKhProvider);

    if (usesDomainHost) {
      return _resolveDomainHostRace(
        providers: orderedProviders,
        movie: movie,
        season: season,
        episode: episode,
        effectiveRanks: effectiveRanks,
        isCancelled: isCancelled,
        onProgress: onProgress,
        animeService: animeService,
        kissKhExtractor: kissKhExtractor,
      );
    }

    return PlaybackEngine.resolveStreamingRace(
      providers: orderedProviders,
      movie: movie,
      season: season,
      episode: episode,
      isCancelled: isCancelled,
      onProgress: onProgress,
      onHitsUpdated: onHitsUpdated,
      maxInFlight: maxInFlight ?? PlaybackEngine.playStartMaxInFlight,
      fillBackgroundHits: fillBackgroundHits,
      effectiveRanks: effectiveRanks,
      settingsOrder: settingsOrder,
      preferredProvider: preferredProvider,
      domain: domain,
    );
  }

  static Future<PlaybackResolveHit?> _resolveDomainHostRace({
    required Map<String, dynamic> providers,
    required Movie movie,
    required int season,
    required int episode,
    required Map<String, int> effectiveRanks,
    bool Function()? isCancelled,
    void Function(String providerId, String status)? onProgress,
    AnimeService? animeService,
    KissKhExtractor? kissKhExtractor,
  }) async {
    final resolver = DomainStreamProviderResolver(
      animeService: animeService,
      kissKhExtractor: kissKhExtractor,
    );
    final cancelled = isCancelled ?? (() => false);
    for (final entry in providers.entries) {
      if (cancelled()) return null;
      final key = entry.key;
      onProgress?.call(key, 'trying');
      final result = await resolver.resolve(
        key: key,
        movie: movie,
        season: season,
        episode: episode,
        providers: providers,
        isCancelled: cancelled,
      );
      if (result == null || result.streamUrl.isEmpty) {
        onProgress?.call(key, 'failed');
        continue;
      }
      final rank = effectiveRanks[key] ?? 0;
      final legacy = result.sources != null && result.sources!.isNotEmpty
          ? result.sources!
          : [
              StreamSource(
                url: result.streamUrl,
                title: 'Primary',
                type: 'hls',
                headers: result.headers,
              ),
            ];
      final ranked = _isKissKhProvider(key)
          ? normalizeLegacyStreamSources(
              sources: legacy,
              providerId: key,
              providerRank: rank,
            )
          : await PlaybackSelection.rankLegacySources(
              sources: legacy,
              providerId: key,
              providerRank: rank,
            );
      if (ranked.isEmpty) {
        onProgress?.call(key, 'failed');
        continue;
      }
      onProgress?.call(key, 'success');
      return PlaybackResolveHit(
        providerId: key,
        providerRank: rank,
        streamUrl: ranked.first.url,
        audioUrl: result.audioUrl,
        headers: result.headers ?? ranked.first.headers,
        sources: ranked,
        subtitles: result.subtitles,
      );
    }
    return null;
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

class StreamProviderResolveResult {
  const StreamProviderResolveResult({
    required this.streamUrl,
    this.audioUrl,
    this.headers,
    this.sources,
    this.subtitles,
  });

  final String streamUrl;
  final String? audioUrl;
  final Map<String, String>? headers;
  final List<StreamSource>? sources;
  final List<Map<String, dynamic>>? subtitles;
}

/// Anime embed + KissKH host resolve (outside Rust Resolver Engine registry).
class DomainStreamProviderResolver {
  DomainStreamProviderResolver({
    AnimeService? animeService,
    KissKhExtractor? kissKhExtractor,
  })  : _animeService = animeService ?? AnimeService(),
        _kissKhExtractor = kissKhExtractor ?? KissKhExtractor();

  final AnimeService _animeService;
  final KissKhExtractor _kissKhExtractor;

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

    if (_isKissKhProvider(key) && payload is Map) {
      return _resolveKissKh(
        key,
        Map<String, dynamic>.from(payload),
        cancelled,
      );
    }

    return null;
  }

  Future<StreamProviderResolveResult?> _resolveAnimeEmbed(
    AnimeEmbed embed,
    bool Function() cancelled,
  ) async {
    if (cancelled()) return null;
    try {
      final candidates = await _animeService.extractDirectCandidates(embed);
      if (cancelled() || candidates.isEmpty) return null;
      final sources = <StreamSource>[];
      String? primaryUrl;
      Map<String, String>? primaryHeaders;
      final subtitles = <Map<String, dynamic>>[];
      for (final direct in candidates) {
        if (direct.url.isEmpty) continue;
        final headers = _animePlaybackHeaders(
          url: direct.url,
          referer: direct.referer,
          origin: direct.origin,
        );
        final title = (direct.streamLabel?.isNotEmpty == true)
            ? direct.streamLabel!
            : 'Stream';
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
            'referer': headers['Referer'] ?? direct.referer,
            'origin': headers['Origin'] ?? direct.origin,
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
    String key,
    Map<String, dynamic> ctx,
    bool Function() cancelled,
  ) async {
    try {
      final forcedBase = (ctx['baseUrl'] as String?)?.trim();
      final baseUrl = (forcedBase != null && forcedBase.isNotEmpty)
          ? forcedBase
          : KissKhService.baseUrlForHost(key);
      final stream = await _kissKhExtractor.resolve(
        dramaId: (ctx['dramaId'] as num).toInt(),
        dramaTitle: ctx['dramaTitle']?.toString() ?? '',
        episodeId: (ctx['episodeId'] as num).toInt(),
        episodeNumber: (ctx['episodeNumber'] as num).toDouble(),
        forcedBaseUrl: baseUrl,
        timeout: const Duration(seconds: 45),
        isCancelled: () => cancelled(),
      );
      if (cancelled() || stream == null) return null;
      final label = KissKhService.mirrorLabel(
        stream.mirrorHost.isNotEmpty ? stream.mirrorHost : key,
      );
      final sources = stream.toSources(label: label);
      return StreamProviderResolveResult(
        streamUrl: sources.first.url,
        headers: sources.first.headers,
        sources: sources,
        subtitles: stream.subtitles,
      );
    } catch (e, st) {
      debugPrint('[DomainStreamProviderResolver] kisskh $key failed: $e\n$st');
      return null;
    }
  }

  void cancelPending() {
    unawaited(_kissKhExtractor.cancel());
    MiruroPipeSession.instance.cancelPending();
  }

  /// Full Sources cancel: host providers + Nuvio + KissKh + Miruro + Engine.
  ///
  /// One entry point for panel switch / panel close / leave title. Do not call
  /// [NuvioService.cancelPending] from UI — it is invoked here.
  static void cancelAllPending({bool cancelEngineJobs = true}) {
    PlaybackEngine.cancelAllPending(cancelEngineJobs: cancelEngineJobs);
    MiruroPipeSession.instance.cancelPending();
  }
}

bool _isKissKhProvider(String key) {
  final id = key.trim().toLowerCase();
  return id == 'kisskh' || KissKhService.isMirrorHost(id);
}

/// Build anime stream headers — omit empty Referer/Origin, then apply CDN rules
/// via [resolvePlaybackHttpHeaders] (mewstream → megaplay, etc.).
Map<String, String> _animePlaybackHeaders({
  required String url,
  required String referer,
  required String origin,
}) {
  final raw = <String, String>{
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
  };
  final r = referer.trim();
  final o = origin.trim();
  if (r.isNotEmpty) raw['Referer'] = r;
  if (o.isNotEmpty) raw['Origin'] = o;
  return resolvePlaybackHttpHeaders(raw, streamUrl: url);
}
