import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/extractors/stream_extractor.dart';
import 'package:forja/shared/nuvio/nuvio.dart';
import 'package:forja/shared/playback/playback_stream_guards.dart';
import 'package:forja/shared/webview/atv_webview_guard.dart';
import 'package:rust/rust.dart';

/// Host-side provider resolution for C3/C4/C5 plugins (WebView, WASM, Nuvio).
abstract final class HostProviderAdapter {
  static final _extractor = StreamExtractor();

  static Future<String?> resolveToSourcesJson({
    required String providerId,
    required String payloadJson,
    required Movie movie,
    required Map<String, dynamic> providers,
    required int season,
    required int episode,
    bool Function()? isCancelled,
  }) async {
    final cancelled = isCancelled ?? (() => false);
    final isTv = movie.mediaType == 'tv';
    final payload = jsonDecode(payloadJson) as Map<String, dynamic>? ?? {};

    if (providerId == 'service111477') {
      final svc = Site111477Service();
      final List<Site111477Match> hits;
      if (isTv) {
        hits = await svc.findEpisodeSources(
          showTitle: movie.title,
          season: season,
          episode: episode,
        );
      } else {
        final year = movie.releaseDate.length >= 4
            ? movie.releaseDate.substring(0, 4)
            : null;
        hits = await svc.findMovieSources(title: movie.title, year: year);
      }
      if (cancelled() || hits.isEmpty) return null;
      final sources = Site111477Service.toStreamSources(hits);
      return jsonEncode(
        sources
            .map(
              (s) => {
                'url': s.url,
                'title': s.title,
                'container': s.type,
                if (s.headers != null) 'headers': s.headers,
              },
            )
            .toList(),
      );
    }

    if (providerId == 'videasy') {
      final result = await VideasyExtractor(onLog: debugPrint).extract(
        tmdbId: movie.id.toString(),
        isMovie: !isTv,
        title: movie.title,
        year: VideasyExtractor.yearFromReleaseDate(movie.releaseDate),
        imdbId: movie.imdbId,
        season: isTv ? season : null,
        episode: isTv ? episode : null,
        totalSeasons: isTv ? movie.numberOfSeasons : null,
        isCancelled: cancelled,
      );
      if (cancelled() || result == null || result.url.isEmpty) return null;
      return _encodeResolveResult(
        url: result.url,
        sources: result.sources,
        headers: result.headers,
      );
    }

    if (providerId.startsWith('nuvio') || providerId == 'nuvio') {
      final scraperId = providerId.contains(':')
          ? providerId.split(':').last
          : payload['scraperId']?.toString() ?? '';
      if (scraperId.isEmpty) return null;
      final results = await NuvioService.instance.runOneScraper(
        scraperId: scraperId,
        tmdbId: movie.id.toString(),
        type: isTv ? 'tv' : 'movie',
        season: isTv ? season : null,
        episode: isTv ? episode : null,
      );
      if (cancelled() || results.isEmpty) return null;
      final direct =
          results.where((r) => !isTorrentStreamUrl(r.url)).toList();
      if (direct.isEmpty) return null;
      return jsonEncode(
        direct
            .map(
              (r) => {
                'url': r.url,
                'title': r.title.isNotEmpty ? r.title : r.name,
                'container': _typeFromUrl(r.url),
                if (r.headers.isNotEmpty) 'headers': r.headers,
              },
            )
            .toList(),
      );
    }

    final embedUrl = payload['embedUrl']?.toString();
    if (embedUrl != null && embedUrl.isNotEmpty) {
      if (isAndroidTvHeadlessWebViewBlocked) return null;
      final result = await _extractor.extract(
        embedUrl,
        timeout: _embedSniffTimeout(providerId),
        isCancelled: cancelled,
        providerId: providerId,
      );
      if (cancelled() || result == null || result.url.isEmpty) return null;
      return _encodeResolveResult(
        url: result.url,
        sources: result.sources,
        headers: result.headers,
      );
    }

    final provider = providers[providerId];
    if (provider == null || provider['movie'] == null || provider['tv'] == null) {
      return null;
    }
    if (isAndroidTvHeadlessWebViewBlocked) return null;
    final String url = isTv
        ? provider['tv'](movie.id.toString(), season, episode)
        : provider['movie'](movie.id.toString());
    final result = await _extractor.extract(
      url,
      timeout: _embedSniffTimeout(providerId),
      isCancelled: cancelled,
      providerId: providerId,
    );
    if (cancelled() || result == null || result.url.isEmpty) return null;
    return _encodeResolveResult(
      url: result.url,
      sources: result.sources,
      headers: result.headers,
    );
  }

  static void cancelAllPending() {
    WebStreamrService().cancelPending();
    VidsrcExtractor.cancelPending();
    VideasyExtractor.cancelPending();
    NuvioService.instance.cancelPending();
    Engine.cancelPendingResolve();
    unawaited(_extractor.cancel());
  }

  static String _encodeResolveResult({
    required String url,
    List<StreamSource>? sources,
    Map<String, String>? headers,
  }) {
    if (sources != null && sources.isNotEmpty) {
      return jsonEncode(
        sources
            .map(
              (s) => {
                'url': s.url,
                'title': s.title,
                'container': s.type,
                if (s.headers != null) 'headers': s.headers,
              },
            )
            .toList(),
      );
    }
    return jsonEncode([
      {
        'url': url,
        'title': 'Primary',
        'container': _typeFromUrl(url),
        if (headers != null) 'headers': headers,
      },
    ]);
  }

  static String _typeFromUrl(String url) {
    final u = url.toLowerCase();
    if (u.contains('.m3u8')) return 'hls';
    if (u.contains('.mpd')) return 'dash';
    if (u.contains('.mkv')) return 'mkv';
    return 'mp4';
  }

  static Duration _embedSniffTimeout(String providerId) {
    switch (providerId) {
      case 'smashystream':
      case 'superembed':
      case 'vixsrc':
      case 'vidnest':
      case 'vidlink':
        return const Duration(seconds: 60);
      default:
        return const Duration(seconds: 45);
    }
  }
}
