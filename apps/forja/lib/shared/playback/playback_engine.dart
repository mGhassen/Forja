import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/playback/stream_provider_resolver.dart';
import 'package:rust/rust.dart';

/// Playback orchestrator — parallel resolve + ranked candidates.
abstract final class PlaybackEngine {
  static const playStartMaxInFlight = 6;

  /// Race providers with limited concurrency. Returns the first successful hit.
  ///
  /// By default stops launching more providers after the first success
  /// ([fillBackgroundHits] = false) so open stays light — other servers resolve
  /// only when the user picks them in the player menu.
  static Future<PlaybackResolveHit?> resolveStreamingRace({
    required Map<String, dynamic> providers,
    required Movie movie,
    required int season,
    required int episode,
    StreamProviderResolver? resolver,
    bool Function()? isCancelled,
    void Function(String providerId, String status)? onProgress,
    void Function(List<PlaybackResolveHit> hits)? onHitsUpdated,
    int maxInFlight = 1,
    bool fillBackgroundHits = false,
    Map<String, int>? effectiveRanks,
  }) async {
    final cancelled = isCancelled ?? (() => false);
    final keys = providers.keys.toList();
    if (keys.isEmpty) return null;
    final r = resolver ?? StreamProviderResolver();
    final taskResolvers = <StreamProviderResolver>[];

    void cancelInFlightResolvers() {
      for (final taskResolver in taskResolvers) {
        taskResolver.cancelPending();
      }
      taskResolvers.clear();
      r.cancelPending();
    }

    final launchCompleter = Completer<PlaybackResolveHit?>();
    final hits = <PlaybackResolveHit>[];
    var settled = 0;
    var inFlight = 0;
    var nextIndex = 0;
    var stopLaunching = false;
    final total = keys.length;
    late void Function() pump;

    void publishHits() {
      if (hits.isEmpty) return;
      hits.sort((a, b) => a.providerRank.compareTo(b.providerRank));
      onHitsUpdated?.call(List.of(hits));
    }

    void finishIfOpen() {
      if (launchCompleter.isCompleted) return;
      publishHits();
      launchCompleter.complete(hits.isEmpty ? null : hits.first);
    }

    void onResolved(String key, PlaybackResolveHit? hit) {
      settled++;
      inFlight--;
      if (hit != null) {
        hits.add(hit);
        publishHits();
        if (!launchCompleter.isCompleted) {
          finishIfOpen();
          if (!fillBackgroundHits) {
            stopLaunching = true;
            nextIndex = total;
            cancelInFlightResolvers();
          }
        }
      }
      if (settled >= total || (stopLaunching && inFlight == 0)) {
        finishIfOpen();
      }
      pump();
    }

    pump = () {
      while (!cancelled() &&
          !stopLaunching &&
          inFlight < maxInFlight &&
          nextIndex < total) {
        final key = keys[nextIndex];
        final rank = effectiveRanks?[key] ?? nextIndex;
        nextIndex++;
        inFlight++;
        onProgress?.call(key, 'trying');
        final taskResolver =
            maxInFlight > 1 ? StreamProviderResolver() : r;
        if (maxInFlight > 1) taskResolvers.add(taskResolver);
        if (kDebugMode && maxInFlight > 1) {
          debugPrint(
            '[PlaybackEngine] probing $key '
            '($inFlight/$maxInFlight in flight, $nextIndex/$total queued)',
          );
        }
        _resolveOne(
          resolver: taskResolver,
          key: key,
          movie: movie,
          season: season,
          episode: episode,
          providers: providers,
          providerRank: rank,
          isCancelled: () => cancelled() || stopLaunching,
          onProgress: onProgress,
        ).then((hit) {
          if (maxInFlight > 1) taskResolvers.remove(taskResolver);
          onResolved(key, hit);
        }).catchError((Object e, StackTrace st) {
          debugPrint('[PlaybackEngine] $key failed: $e\n$st');
          onProgress?.call(key, 'failed');
          onResolved(key, null);
        });
      }
      if (nextIndex >= total && inFlight == 0) {
        finishIfOpen();
      }
    };

    pump();
    return launchCompleter.future;
  }

  /// Legacy batch resolve — prefer [resolveStreamingRace] for play start.
  static Future<PlaybackResolveHit?> resolveParallel({
    required Map<String, dynamic> providers,
    required Movie movie,
    required int season,
    required int episode,
    StreamProviderResolver? resolver,
    bool Function()? isCancelled,
    void Function(String providerId, String status)? onProgress,
  }) =>
      resolveStreamingRace(
        providers: providers,
        movie: movie,
        season: season,
        episode: episode,
        resolver: resolver,
        isCancelled: isCancelled,
        onProgress: onProgress,
      );

  static List<StreamSource> mergeHitSources(List<PlaybackResolveHit> hits) {
    if (hits.isEmpty) return const [];
    final sorted = List<PlaybackResolveHit>.from(hits)
      ..sort((a, b) => a.providerRank.compareTo(b.providerRank));
    return dedupeSourcesByUrl(
      sorted.expand((h) => h.streamSources).toList(),
    );
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

  static Future<PlaybackResolveHit?> _resolveOne({
    required StreamProviderResolver resolver,
    required String key,
    required Movie movie,
    required int season,
    required int episode,
    required Map<String, dynamic> providers,
    required int providerRank,
    required bool Function() isCancelled,
    void Function(String providerId, String status)? onProgress,
  }) async {
    try {
      final result = await resolver.resolve(
        key: key,
        movie: movie,
        season: season,
        episode: episode,
        providers: providers,
        isCancelled: isCancelled,
      );
      if (isCancelled() || result == null || result.streamUrl.isEmpty) {
        onProgress?.call(key, 'failed');
        return null;
      }
      final raw = result.sources;
      final legacy = raw != null && raw.isNotEmpty
          ? raw
          : [
              StreamSource(
                url: result.streamUrl,
                title: 'Primary',
                type: _typeFromUrl(result.streamUrl),
                headers: result.headers,
              ),
            ];
      final ranked = await PlaybackSelection.rankLegacySources(
        sources: legacy,
        providerId: key,
        providerRank: providerRank,
      );
      if (ranked.isEmpty) {
        onProgress?.call(key, 'failed');
        return null;
      }
      onProgress?.call(key, 'success');
      return PlaybackResolveHit(
        providerId: key,
        providerRank: providerRank,
        streamUrl: ranked.first.url,
        audioUrl: result.audioUrl,
        headers: result.headers ?? ranked.first.headers,
        sources: ranked,
        subtitles: result.subtitles,
      );
    } catch (e, st) {
      debugPrint('[PlaybackEngine] $key failed: $e\n$st');
      onProgress?.call(key, 'failed');
      return null;
    }
  }

  static String _typeFromUrl(String url) {
    final u = url.toLowerCase();
    if (u.contains('.m3u8')) return 'hls';
    if (u.contains('.mpd')) return 'dash';
    if (u.contains('.mkv')) return 'mkv';
    return 'mp4';
  }
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
