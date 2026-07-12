import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/playback/stream_provider_resolver.dart';
import 'package:rust/rust.dart';

/// Playback orchestrator — parallel resolve + ranked candidates.
abstract final class PlaybackEngine {
  static const maxParallelProviders = 3;

  /// Race providers in parallel (cap [maxParallelProviders]).
  static Future<PlaybackResolveHit?> resolveParallel({
    required Map<String, dynamic> providers,
    required Movie movie,
    required int season,
    required int episode,
    StreamProviderResolver? resolver,
    bool Function()? isCancelled,
    void Function(String providerId, String status)? onProgress,
  }) async {
    final cancelled = isCancelled ?? (() => false);
    final keys = providers.keys.toList();
    if (keys.isEmpty) return null;
    final r = resolver ?? StreamProviderResolver();

    for (var batch = 0; batch < keys.length; batch += maxParallelProviders) {
      if (cancelled()) return null;
      final chunk = keys.skip(batch).take(maxParallelProviders).toList();
      final futures = <Future<PlaybackResolveHit?>>[];
      for (var i = 0; i < chunk.length; i++) {
        final key = chunk[i];
        final rank = batch + i;
        onProgress?.call(key, 'trying');
        futures.add(
          _resolveOne(
            resolver: r,
            key: key,
            movie: movie,
            season: season,
            episode: episode,
            providers: providers,
            providerRank: rank,
            isCancelled: cancelled,
            onProgress: onProgress,
          ),
        );
      }
      final results = await Future.wait(futures);
      final hits = results.whereType<PlaybackResolveHit>().toList();
      if (hits.isEmpty) continue;
      hits.sort((a, b) => a.providerRank.compareTo(b.providerRank));
      final best = hits.first;
      onProgress?.call(best.providerId, 'success');
      return best;
    }
    return null;
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
