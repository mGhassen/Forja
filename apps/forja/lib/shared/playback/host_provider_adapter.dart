import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/extractors/embed_extract_profiles.dart';
import 'package:forja/shared/extractors/core/stream_extractor.dart';
import 'package:forja/shared/extractors/providers/videasy/videasy_extractor.dart';
import 'package:forja/shared/extractors/providers/vidnest/vidnest_extractor.dart';
import 'package:forja/shared/extractors/providers/vidsrc/vidsrc_extractor.dart';
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
      if (!cancelled() && result != null && result.url.isNotEmpty) {
        return _encodeResolveResult(
          url: result.url,
          sources: result.sources,
          headers: result.headers,
        );
      }
      // Dart HTTP to wingsdatabase often CF-blocks/timeouts while the live
      // player works. Fall back to sniffing player.videasy.to (same as browser).
      if (cancelled() || isAndroidTvHeadlessWebViewBlocked) return null;
      final embed = isTv
          ? 'https://player.videasy.to/tv/${movie.id}/$season/$episode'
          : 'https://player.videasy.to/movie/${movie.id}';
      debugPrint('[videasy] API empty — sniffing $embed');
      final profile = EmbedExtractProfiles.resolve('videasy');
      final sniffed = await _extractor.extract(
        embed,
        profile: profile,
        referer: embed,
        isCancelled: cancelled,
        providerId: 'videasy',
      );
      if (cancelled() || sniffed == null || sniffed.url.isEmpty) return null;
      return _encodeResolveResult(
        url: sniffed.url,
        sources: sniffed.sources,
        headers: sniffed.headers,
      );
    }

    if (providerId == 'vidnest') {
      final result = await VidnestExtractor(onLog: debugPrint).extract(
        tmdbId: movie.id.toString(),
        isMovie: !isTv,
        season: isTv ? season : null,
        episode: isTv ? episode : null,
        isCancelled: cancelled,
      );
      if (!cancelled() && result != null && result.url.isNotEmpty) {
        return _encodeResolveResult(
          url: result.url,
          sources: result.sources,
          headers: result.headers,
        );
      }
      // API empty — fall through to embed WebView sniff.
      if (cancelled() || isAndroidTvHeadlessWebViewBlocked) return null;
      final fromPayload = payload['embedUrl']?.toString();
      final embed = (fromPayload != null && fromPayload.isNotEmpty)
          ? fromPayload
          : (isTv
                ? 'https://vidnest.fun/tv/${movie.id}/$season/$episode'
                : 'https://vidnest.fun/movie/${movie.id}');
      debugPrint('[vidnest] API empty — sniffing $embed');
      final profile = EmbedExtractProfiles.resolve('vidnest');
      final sniffed = await _extractor.extract(
        embed,
        profile: profile,
        referer: embed,
        isCancelled: cancelled,
        providerId: 'vidnest',
      );
      if (cancelled() || sniffed == null || sniffed.url.isEmpty) return null;
      return _encodeResolveResult(
        url: sniffed.url,
        sources: sniffed.sources,
        headers: sniffed.headers,
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
      final direct = results.where((r) => !isTorrentStreamUrl(r.url)).toList();
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
      final profile = EmbedExtractProfiles.resolve(providerId);
      final result = await _extractor.extract(
        embedUrl,
        profile: profile,
        referer: embedUrl,
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
    if (provider == null ||
        provider['movie'] == null ||
        provider['tv'] == null) {
      return null;
    }
    if (isAndroidTvHeadlessWebViewBlocked) return null;
    final String url = isTv
        ? provider['tv'](movie.id.toString(), season, episode)
        : provider['movie'](movie.id.toString());
    final profile = EmbedExtractProfiles.resolve(providerId);
    final result = await _extractor.extract(
      url,
      profile: profile,
      referer: url,
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
    VidnestExtractor.cancelPending();
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
      final playable = sources
          .where((s) => !isUnplayableCachedStreamUrl(s.url))
          .toList();
      if (playable.isEmpty) {
        return '[]';
      }
      return jsonEncode(
        playable
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
    if (isUnplayableCachedStreamUrl(url)) {
      return '[]';
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
}
