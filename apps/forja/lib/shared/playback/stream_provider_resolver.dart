import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/extractors/stream_extractor.dart';
import 'package:forja/shared/nuvio/nuvio.dart';
import 'package:rust/rust.dart';
import 'package:rust/rust.dart' as site111477_proxy;

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

class StreamProviderResolver {
  StreamProviderResolver({StreamExtractor? extractor})
      : _extractor = extractor ?? StreamExtractor();

  final StreamExtractor _extractor;

  Future<StreamProviderResolveResult?> resolve({
    required String key,
    required Movie movie,
    required int season,
    required int episode,
    required Map<String, dynamic> providers,
    bool Function()? isCancelled,
  }) async {
    final cancelled = isCancelled ?? (() => false);
    final isTv = movie.mediaType == 'tv';

    if (key == 'service111477') {
      final svc = Site111477Service();
      final List<Site111477Match> hits;
      if (isTv) {
        hits = await svc.findEpisodeSources(
          showTitle: movie.title,
          season: season,
          episode: episode,
        );
      } else {
        final year =
            movie.releaseDate.length >= 4 ? movie.releaseDate.substring(0, 4) : null;
        hits = await svc.findMovieSources(title: movie.title, year: year);
      }
      if (cancelled() || hits.isEmpty) return null;
      final proxiedUrl = await site111477_proxy.start111477Proxy(hits.first.fileUrl);
      if (cancelled()) return null;
      return StreamProviderResolveResult(
        streamUrl: proxiedUrl,
        sources: Site111477Service.toStreamSources(hits),
      );
    }

    if (key == 'webstreamr') {
      if (movie.imdbId == null || movie.imdbId!.isEmpty) return null;
      final wsSources = await WebStreamrService().getStreams(
        imdbId: movie.imdbId!,
        isMovie: !isTv,
        season: isTv ? season : null,
        episode: isTv ? episode : null,
        tmdbId: movie.id,
      );
      if (cancelled() || wsSources.isEmpty) return null;
      final first = wsSources.first;
      return StreamProviderResolveResult(
        streamUrl: first.url,
        headers: first.headers,
        sources: wsSources,
      );
    }

    if (key == 'videasy') {
      final result = await VideasyExtractor(onLog: debugPrint).extract(
        tmdbId: movie.id.toString(),
        isMovie: !isTv,
        season: isTv ? season : null,
        episode: isTv ? episode : null,
        isCancelled: cancelled,
      );
      if (cancelled() || result == null || result.url.isEmpty) return null;
      return StreamProviderResolveResult(
        streamUrl: result.url,
        audioUrl: result.audioUrl,
        headers: result.headers,
        sources: result.sources,
        subtitles: result.externalSubtitles,
      );
    }

    if (key == 'vidsrc') {
      final result = await VidsrcExtractor().extract(
        tmdbId: movie.id.toString(),
        isMovie: !isTv,
        season: isTv ? season : null,
        episode: isTv ? episode : null,
      );
      if (cancelled() || result == null || result.url.isEmpty) return null;
      return StreamProviderResolveResult(
        streamUrl: result.url,
        audioUrl: result.audioUrl,
        headers: result.headers,
        sources: result.sources,
        subtitles: result.externalSubtitles,
      );
    }

    if (key.startsWith('nuvio:')) {
      final scraperId = key.substring(6);
      final results = await NuvioService.instance.runOneScraper(
        scraperId: scraperId,
        tmdbId: movie.id.toString(),
        type: isTv ? 'tv' : 'movie',
        season: isTv ? season : null,
        episode: isTv ? episode : null,
      );
      if (cancelled() || results.isEmpty) return null;
      final first = results.first;
      final sources = results
          .map(
            (r) => StreamSource(
              url: r.url,
              title: r.title.isNotEmpty ? r.title : r.name,
              type: _typeFromUrl(r.url),
              headers: r.headers.isEmpty ? null : r.headers,
            ),
          )
          .toList();
      final subtitles = first.subtitles
          .where((s) => (s['url'] ?? '').isNotEmpty)
          .map(
            (s) => <String, dynamic>{
              'url': s['url']!,
              'lang': s['lang'] ?? 'Unknown',
            },
          )
          .toList();
      return StreamProviderResolveResult(
        streamUrl: first.url,
        headers: first.headers.isEmpty ? null : first.headers,
        sources: sources,
        subtitles: subtitles,
      );
    }

    final provider = providers[key];
    if (provider == null || provider['movie'] == null || provider['tv'] == null) {
      return null;
    }
    if (SettingsService.platformProfile == PlatformProfile.androidTv) {
      debugPrint(
        '[StreamProviderResolver] WebView sniffer skipped on Android TV for $key',
      );
      return null;
    }
    final String url = isTv
        ? provider['tv'](movie.id.toString(), season, episode)
        : provider['movie'](movie.id.toString());
    final result = await _extractor.extract(
      url,
      timeout: const Duration(seconds: 5),
      isCancelled: cancelled,
    );
    if (cancelled() || result == null) return null;
    return StreamProviderResolveResult(
      streamUrl: result.url,
      audioUrl: result.audioUrl,
      headers: result.headers,
      sources: result.sources,
      subtitles: result.externalSubtitles,
    );
  }

  void cancelPending() {
    WebStreamrService().cancelPending();
    VidsrcExtractor.cancelPending();
    NuvioService.instance.cancelPending();
    unawaited(_extractor.cancel());
  }

  String _typeFromUrl(String url) {
    final u = url.toLowerCase();
    if (u.contains('.m3u8')) return 'hls';
    if (u.contains('.mpd')) return 'dash';
    if (u.contains('.mkv')) return 'mkv';
    return 'mp4';
  }
}
