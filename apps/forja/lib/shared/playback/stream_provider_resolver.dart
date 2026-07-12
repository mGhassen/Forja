import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/extractors/stream_extractor.dart';
import 'package:forja/shared/nuvio/nuvio.dart';
import 'package:rust/rust.dart';
import 'package:rust/rust.dart' as site111477_proxy;

/// A magnet / torrent link — NOT a direct HTTP(S) stream.
///
/// Direct Streaming (green Play) must only ever play direct URLs. Some Nuvio
/// scrapers (e.g. Torrentio) return magnets; those belong in the torrent
/// Sources panel + local torrent engine, never in the direct-streaming race.
bool isTorrentStreamUrl(String url) {
  final u = url.trim().toLowerCase();
  return u.startsWith('magnet:') ||
      u.contains('urn:btih:') ||
      u.endsWith('.torrent');
}

/// Placeholder / relative URLs must never ship in webstreaming session or disk cache.
bool isUnplayableCachedStreamUrl(String url) {
  final u = url.trim();
  if (u.isEmpty) return true;
  if (isTorrentStreamUrl(u)) return true;
  final lower = u.toLowerCase();
  if (lower.contains('demo-video')) return true;
  if (u.startsWith('/') && !u.startsWith('//')) return true;
  if (!u.contains('://')) return true;
  return false;
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
      if (movie.id <= 0) return null;
      final imdb = movie.imdbId?.trim() ?? '';
      final releaseYear = movie.releaseDate.length >= 4
          ? int.tryParse(movie.releaseDate.substring(0, 4))
          : null;
      final wsSources = await WebStreamrService().getStreams(
        imdbId: imdb,
        isMovie: !isTv,
        season: isTv ? season : null,
        episode: isTv ? episode : null,
        tmdbId: movie.id,
        title: movie.title,
        year: releaseYear,
      );
      if (!cancelled() && wsSources.isNotEmpty) {
        final first = wsSources.first;
        return StreamProviderResolveResult(
          streamUrl: first.url,
          headers: first.headers,
          sources: wsSources,
        );
      }
      if (cancelled()) return null;
      return _webstreamrVidsrcWebViewFallback(
        movie: movie,
        isTv: isTv,
        season: season,
        episode: episode,
        isCancelled: cancelled,
      );
    }

    if (key == 'videasy') {
      final result = await VideasyExtractor(onLog: debugPrint).extract(
        tmdbId: movie.id.toString(),
        isMovie: !isTv,
        title: movie.title,
        year: VideasyExtractor.yearFromReleaseDate(movie.releaseDate),
        imdbId: movie.imdbId,
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
      // Direct Streaming is direct HTTP(S) only. Drop any magnet/torrent
      // links a scraper returns (e.g. Torrentio) so the green Play path never
      // hands a torrent to the direct player. Torrent links stay available in
      // the Sources panel, which routes them through the torrent engine.
      final directResults =
          results.where((r) => !isTorrentStreamUrl(r.url)).toList();
      if (directResults.isEmpty) return null;
      final first = directResults.first;
      final sources = directResults
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

  /// VidSrc embeds often need a real browser (JS + sandbox checks). When the
  /// Rust WebStreamr aggregator returns nothing, sniff the VidSrc embed like
  /// template providers — PlayTorrio-style fallback for older titles.
  Future<StreamProviderResolveResult?> _webstreamrVidsrcWebViewFallback({
    required Movie movie,
    required bool isTv,
    required int season,
    required int episode,
    required bool Function() isCancelled,
  }) async {
    if (SettingsService.platformProfile == PlatformProfile.androidTv) {
      debugPrint(
        '[StreamProviderResolver] WebStreamr VidSrc WebView fallback skipped on Android TV',
      );
      return null;
    }
    final rawId = movie.imdbId?.trim().split(':').first ?? '';
    final id = rawId.isNotEmpty ? rawId : movie.id.toString();
    if (id.isEmpty) return null;

    final url = isTv
        ? 'https://vidsrc-embed.ru/embed/tv/$id/$season-$episode'
        : 'https://vidsrc-embed.ru/embed/movie/$id';

    if (kDebugMode) {
      debugPrint(
        '[StreamProviderResolver] WebStreamr Rust empty — VidSrc WebView fallback $url',
      );
    }

    final result = await _extractor.extract(
      url,
      timeout: const Duration(seconds: 45),
      isCancelled: isCancelled,
    );
    if (isCancelled() || result == null || result.url.isEmpty) return null;

    final sources = result.sources != null && result.sources!.isNotEmpty
        ? result.sources!
        : [
            StreamSource(
              url: result.url,
              title: 'WebStreamr',
              type: _typeFromUrl(result.url),
              headers: result.headers,
            ),
          ];

    return StreamProviderResolveResult(
      streamUrl: result.url,
      audioUrl: result.audioUrl,
      headers: result.headers,
      sources: sources,
      subtitles: result.externalSubtitles,
    );
  }

  void cancelPending() {
    WebStreamrService().cancelPending();
    VidsrcExtractor.cancelPending();
    VideasyExtractor.cancelPending();
    NuvioService.instance.cancelPending();
    Engine.cancelPendingResolve();
    unawaited(_extractor.cancel());
  }

  /// Host-wide abort for player exit / provider switch.
  static void cancelAllPending() {
    WebStreamrService().cancelPending();
    VidsrcExtractor.cancelPending();
    VideasyExtractor.cancelPending();
    NuvioService.instance.cancelPending();
    Engine.cancelPendingResolve();
  }

  String _typeFromUrl(String url) {
    final u = url.toLowerCase();
    if (u.contains('.m3u8')) return 'hls';
    if (u.contains('.mpd')) return 'dash';
    if (u.contains('.mkv')) return 'mkv';
    return 'mp4';
  }
}
