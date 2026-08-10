import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/playback/host_provider_adapter.dart';
import 'package:forja/shared/playback/tv_stream_fallback.dart';
import 'package:forja/shared/webview/atv_webview_guard.dart';
import 'package:rust/rust.dart';

/// Playback orchestrator - delegates resolve race to the Rust Resolver Engine.
abstract final class PlaybackEngine {
  static const playStartMaxInFlight = 2;

  /// Race providers via [ResolverEngineClient]. Returns the first successful hit.
  static Future<PlaybackResolveHit?> resolveStreamingRace({
    required Map<String, dynamic> providers,
    required Movie movie,
    required int season,
    required int episode,
    Object? resolver,
    bool Function()? isCancelled,
    void Function(String providerId, String status)? onProgress,
    void Function(List<PlaybackResolveHit> hits)? onHitsUpdated,
    int maxInFlight = 1,
    bool fillBackgroundHits = false,
    Map<String, int>? effectiveRanks,
    List<String> settingsOrder = const [],
    String preferredProvider = SourceEngine.auto,
    SourceDomain? domain,
  }) async {
    final cancelled = isCancelled ?? (() => false);
    if (providers.isEmpty) return null;

    final resolveDomain = domain ?? SourceDomain.fromMediaType(movie.mediaType);

    void reportProgress(List<dynamic>? events) {
      if (events == null) return;
      for (final raw in events) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final id =
            map['providerId']?.toString() ?? map['provider_id']?.toString();
        final status = map['status']?.toString();
        if (id != null && status != null) {
          onProgress?.call(id, status);
        }
      }
    }

    try {
      final request = await ResolverEngineClient.buildRequest(
        domain: resolveDomain,
        movie: movie,
        season: season,
        episode: episode,
        providers: providers,
        settingsOrder: settingsOrder,
        preferred: preferredProvider,
        skipHostOnTv: isAndroidTvHeadlessWebViewBlocked,
        maxInFlight: maxInFlight,
      );

      if (cancelled()) return null;

      var response = await ResolverEngineClient.resolve(request: request);
      reportProgress(response['progress'] as List<dynamic>?);

      if (cancelled()) {
        HostProviderAdapter.cancelAllPending();
        return null;
      }

      // Host providers continue one-by-one in score order: Rust pauses for a
      // single host, we fulfill it, continue may pause again for the next.
      while ((response['phase']?.toString() ?? '') == 'awaiting_host') {
        final sessionId = response['sessionId']?.toString() ?? '';
        final hostRequests = response['hostRequests'] as List<dynamic>? ?? [];
        if (sessionId.isEmpty || hostRequests.isEmpty) break;

        final orderedHosts =
            hostRequests.whereType<Map>().map((raw) {
              return Map<String, dynamic>.from(raw);
            }).toList()..sort((a, b) {
              final idA =
                  a['providerId']?.toString() ??
                  a['provider_id']?.toString() ??
                  '';
              final idB =
                  b['providerId']?.toString() ??
                  b['provider_id']?.toString() ??
                  '';
              final rankA = effectiveRanks?[idA] ?? 1 << 20;
              final rankB = effectiveRanks?[idB] ?? 1 << 20;
              return rankA.compareTo(rankB);
            });

        final hostResults = <Map<String, dynamic>>[];

        for (final req in orderedHosts) {
          if (cancelled()) {
            HostProviderAdapter.cancelAllPending();
            return null;
          }
          final providerId =
              req['providerId']?.toString() ?? req['provider_id']?.toString();
          if (providerId == null || providerId.isEmpty) continue;

          if (TvStreamFallback.isSkippedOnTv(providerId, providers)) {
            onProgress?.call(providerId, 'skipped');
            hostResults.add({
              'providerId': providerId,
              'sourcesJson': '[]',
              'error': 'skipped_on_tv',
            });
            continue;
          }

          onProgress?.call(providerId, 'trying');
          final sourcesJson = await HostProviderAdapter.resolveToSourcesJson(
            providerId: providerId,
            payloadJson: req['payloadJson']?.toString() ?? '{}',
            movie: movie,
            providers: providers,
            season: season,
            episode: episode,
            isCancelled: cancelled,
          );
          if (sourcesJson == null || sourcesJson == '[]') {
            onProgress?.call(providerId, 'failed');
            hostResults.add({
              'providerId': providerId,
              'sourcesJson': '[]',
              'error': 'no_streams',
            });
            // Score order: report this miss; Rust continue resumes next provider.
            if (!fillBackgroundHits) break;
          } else {
            onProgress?.call(providerId, 'success');
            hostResults.add({
              'providerId': providerId,
              'sourcesJson': sourcesJson,
            });
            if (!fillBackgroundHits) break;
          }
        }

        if (cancelled()) return null;
        if (hostResults.isEmpty) break;

        response = await ResolverEngineClient.continueWithHost(
          sessionId: sessionId,
          hostResults: hostResults,
        );
        reportProgress(response['progress'] as List<dynamic>?);
      }

      final hit = _hitFromResponse(response, effectiveRanks: effectiveRanks);
      if (hit != null) {
        onHitsUpdated?.call([hit]);
      }
      return hit;
    } catch (e, st) {
      debugPrint('[PlaybackEngine] ResolverEngine failed: $e\n$st');
      return null;
    }
  }

  static Future<PlaybackResolveHit?> resolveParallel({
    required Map<String, dynamic> providers,
    required Movie movie,
    required int season,
    required int episode,
    Object? resolver,
    bool Function()? isCancelled,
    void Function(String providerId, String status)? onProgress,
  }) => resolveStreamingRace(
    providers: providers,
    movie: movie,
    season: season,
    episode: episode,
    isCancelled: isCancelled,
    onProgress: onProgress,
  );

  static List<StreamSource> mergeHitSources(List<PlaybackResolveHit> hits) {
    if (hits.isEmpty) return const [];
    final sorted = List<PlaybackResolveHit>.from(hits)
      ..sort((a, b) => a.providerRank.compareTo(b.providerRank));
    return dedupeSourcesByUrl(sorted.expand((h) => h.streamSources).toList());
  }

  static Map<String, List<StreamSource>> hitsToProviderCache(
    List<PlaybackResolveHit> hits,
  ) {
    final out = <String, List<StreamSource>>{};
    for (final hit in hits) {
      out[hit.providerId] = hit.streamSources;
    }
    return out;
  }

  static List<StreamSource> dedupeSourcesByUrl(List<StreamSource> sources) {
    final seen = <String>{};
    final out = <StreamSource>[];
    for (final source in sources) {
      final url = source.url.trim();
      if (url.isEmpty || seen.contains(url)) continue;
      seen.add(url);
      out.add(source);
    }
    return out;
  }

  static PlaybackResolveHit? _hitFromResponse(
    Map<String, dynamic> response, {
    Map<String, int>? effectiveRanks,
  }) {
    final winner = ResolverEngineClient.winnerFromResponse(response);
    if (winner == null || winner.url.isEmpty) return null;

    final sources = ResolverEngineClient.sourcesFromResponse(response);
    final ranked = sources.isNotEmpty ? sources : [winner];
    final providerId =
        response['winnerProviderId']?.toString() ??
        response['winner_provider_id']?.toString() ??
        winner.providerId;
    final rank = effectiveRanks?[providerId] ?? winner.providerRank;

    return PlaybackResolveHit(
      providerId: providerId,
      providerRank: rank,
      streamUrl: winner.url,
      audioUrl: winner.audioUrl,
      headers: winner.headers.isEmpty ? null : winner.headers,
      sources: ranked,
    );
  }

  /// Shared cancel for pending source resolves (webstreaming hosts, Nuvio,
  /// KissKh, optional Engine jobs). Prefer this over provider-specific cancels.
  static void cancelAllPending({bool cancelEngineJobs = true}) =>
      HostProviderAdapter.cancelAllPending(cancelEngineJobs: cancelEngineJobs);
}

class PlaybackResolveHit {
  const PlaybackResolveHit({
    required this.providerId,
    required this.providerRank,
    required this.streamUrl,
    this.audioUrl,
    this.headers,
    required this.sources,
    this.subtitles,
  });

  final String providerId;
  final int providerRank;
  final String streamUrl;
  final String? audioUrl;
  final Map<String, String>? headers;
  final List<PlayableSource> sources;
  final List<Map<String, dynamic>>? subtitles;

  List<StreamSource> get streamSources =>
      playableSourcesToStreamSources(sources);
}
