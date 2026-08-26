import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/extractors/embed_extract_profiles.dart';
import 'package:forja/shared/extractors/core/stream_extractor.dart';
import 'package:forja/shared/extractors/providers/videasy/videasy_extractor.dart';
import 'package:forja/shared/extractors/providers/vidnest/vidnest_extractor.dart';
import 'package:forja/shared/extractors/providers/vidsrc/vidsrc_extractor.dart';
import 'package:forja/shared/extractors/providers/vidsrcsbs/profile.dart';
import 'package:forja/shared/extractors/providers/vidsrcsbs/vidsrcsbs_extractor.dart';
import 'package:forja/shared/extractors/providers/kisskh/kisskh_extractor.dart';
import 'package:forja/shared/nuvio/nuvio.dart';
import 'package:forja/shared/engine/service.dart';
import 'package:forja/shared/playback/playback_stream_guards.dart';
import 'package:forja/shared/webview/atv_webview_guard.dart';
import 'package:rust/rust.dart';

/// Host-side provider resolution for C3/C4/C5 plugins (WebView, WASM, Nuvio).
abstract final class HostProviderAdapter {
  static final _extractor = StreamExtractor();

  /// Extra headless sniffs for bounded parallel multi-mirror collect.
  static final _parallelExtractors = <StreamExtractor>[];

  /// Cap concurrent nested WebView sniffs (VidSrc.sbs mirrors, …).
  static const _webviewSniffConcurrency = 2;

  @visibleForTesting
  static int get vidsrcsbsWebviewSniffConcurrencyForTest =>
      _webviewSniffConcurrency;

  @visibleForTesting
  static bool vidsrcsbsUsesStreamCrypto(String nestedUrl) =>
      VideasyExtractor.isStreamCryptoPlayerUrl(nestedUrl);

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
      if (sources.isEmpty) return null;
      return _encodeResolveResult(
        url: sources.first.url,
        sources: sources,
        headers: sources.first.headers,
        providerId: providerId,
      );
    }

    if (providerId == 'vidsrc') {
      // Legacy rcp→prorcp HTML chain (fast when it still works).
      final rust = await VidsrcExtractor().extract(
        tmdbId: movie.id.toString(),
        isMovie: !isTv,
        season: isTv ? season : null,
        episode: isTv ? episode : null,
      );
      if (!cancelled() && rust != null && rust.url.isNotEmpty) {
        return _encodeResolveResult(
          url: rust.url,
          sources: rust.sources,
          headers: rust.headers,
          providerId: providerId,
        );
      }
      // Live player is JS/WASM (cloudorchestranova + vsdec). Sniff embed.
      if (cancelled() || isAndroidTvHeadlessWebViewBlocked) return null;
      final embed = VidsrcExtractor.buildEmbedUrl(
        tmdbId: movie.id.toString(),
        isMovie: !isTv,
        season: isTv ? season : null,
        episode: isTv ? episode : null,
      );
      if (embed.isEmpty) return null;
      debugPrint('[VSEmbed] Rust empty - sniffing $embed');
      final sniffed = await _extractor.extract(
        embed,
        profile: EmbedExtractProfiles.resolve('vidsrc'),
        referer: embed,
        isCancelled: cancelled,
        providerId: 'vidsrc',
      );
      if (sniffed == null || sniffed.url.isEmpty) return null;
      return _encodeResolveResult(
        url: sniffed.url,
        sources: sniffed.sources,
        headers: sniffed.headers,
        providerId: providerId,
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
          providerId: providerId,
        );
      }
      // API empty/CF-block: sniff player.videasy.to Servers dropdown one by
      // one (Yoru/Cypher/…) and keep every playlist that emits.
      if (cancelled() || isAndroidTvHeadlessWebViewBlocked) return null;
      final embed = isTv
          ? 'https://player.videasy.to/tv/${movie.id}/$season/$episode'
          : 'https://player.videasy.to/movie/${movie.id}';
      debugPrint('[videasy] API empty - sniffing servers on $embed');
      final profile = EmbedExtractProfiles.resolve('videasy');
      final sniffed = await _extractor.extract(
        embed,
        profile: profile,
        referer: embed,
        isCancelled: cancelled,
        providerId: 'videasy',
      );
      // Keep a successful sniff even if cancel raced the completer (manual
      // provider switch / race teardown). cancel() now completes with capture.
      if (sniffed == null || sniffed.url.isEmpty) return null;
      return _encodeResolveResult(
        url: sniffed.url,
        sources: sniffed.sources,
        headers: sniffed.headers,
        providerId: providerId,
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
          providerId: providerId,
        );
      }
      // API empty - fall through to embed WebView sniff.
      if (cancelled() || isAndroidTvHeadlessWebViewBlocked) return null;
      final fromPayload = payload['embedUrl']?.toString();
      final embed = (fromPayload != null && fromPayload.isNotEmpty)
          ? fromPayload
          : (isTv
                ? 'https://vidnest.fun/tv/${movie.id}/$season/$episode'
                : 'https://vidnest.fun/movie/${movie.id}');
      debugPrint('[vidnest] API empty - sniffing $embed');
      final profile = EmbedExtractProfiles.resolve('vidnest');
      final sniffed = await _extractor.extract(
        embed,
        profile: profile,
        referer: embed,
        isCancelled: cancelled,
        providerId: 'vidnest',
      );
      if (sniffed == null || sniffed.url.isEmpty) return null;
      return _encodeResolveResult(
        url: sniffed.url,
        sources: sniffed.sources,
        headers: sniffed.headers,
        providerId: providerId,
      );
    }

    if (providerId == 'vidsrcsbs') {
      final fromPayload = payload['embedUrl']?.toString();
      final outerEmbed = (fromPayload != null && fromPayload.isNotEmpty)
          ? fromPayload
          : (isTv
                ? 'https://vidsrc.sbs/embed/tv/${movie.id}/$season/$episode'
                : 'https://vidsrc.sbs/embed/movie/${movie.id}');

      // Parse CFG.servers → sniff every top mirror (bounded parallel). Nested
      // enc=2 player URLs use STREAMCRYPTO HTTP (no WebView). Other mirrors
      // rotate their own Servers chips (Pro Multi internals, …).
      final discovered = await VidsrcsbsExtractor(
        onLog: debugPrint,
      ).discoverServers(embedUrl: outerEmbed, isCancelled: cancelled);
      if (discovered.isNotEmpty) {
        final allSources = await _sniffVidsrcsbsMirrors(
          servers: discovered,
          isMovie: !isTv,
          tmdbId: movie.id.toString(),
          title: movie.title,
          year: VideasyExtractor.yearFromReleaseDate(movie.releaseDate),
          imdbId: movie.imdbId,
          totalSeasons: isTv ? movie.numberOfSeasons : null,
          season: isTv ? season : null,
          episode: isTv ? episode : null,
          outerEmbed: outerEmbed,
          isCancelled: cancelled,
        );
        if (allSources.isNotEmpty) {
          debugPrint(
            '[vidsrcsbs] ${discovered.length} mirror(s) → '
            '${allSources.length} stream(s)',
          );
          return _encodeResolveResult(
            url: allSources.first.url,
            sources: allSources,
            headers: allSources.first.headers,
            providerId: providerId,
          );
        }
      }

      if (cancelled() || isAndroidTvHeadlessWebViewBlocked) return null;
      debugPrint('[vidsrcsbs] nested empty - fallback outer $outerEmbed');
      final outer = await _extractor.extract(
        outerEmbed,
        profile: vidsrcsbsExtractProfile,
        referer: outerEmbed,
        isCancelled: cancelled,
        providerId: 'vidsrcsbs',
      );
      if (outer == null || outer.url.isEmpty) return null;
      return _encodeResolveResult(
        url: outer.url,
        sources: outer.sources,
        headers: outer.headers,
        providerId: providerId,
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
                'providerId': providerId,
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
      if (result == null || result.url.isEmpty) return null;
      return _encodeResolveResult(
        url: result.url,
        sources: result.sources,
        headers: result.headers,
        providerId: providerId,
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
    if (result == null || result.url.isEmpty) return null;
    return _encodeResolveResult(
      url: result.url,
      sources: result.sources,
      headers: result.headers,
      providerId: providerId,
    );
  }

  /// Abort every in-flight host / Nuvio / KissKh extract.
  ///
  /// This is the shared cancel used by webstreaming, Sources panels, and
  /// leave-title paths. Call sites must not special-case Nuvio.
  ///
  /// When [cancelEngineJobs] is false (user picked a torrent/Stremio row and
  /// resolve is about to start, or the player is tearing down), skip
  /// [Engine.cancelPendingResolve] so magnet / torrentStream jobs stay alive.
  /// Provider cancelPending() only bumps generations - they must not cancel
  /// Engine jobs themselves.
  static void cancelAllPending({bool cancelEngineJobs = true}) {
    WebStreamrService().cancelPending();
    VidsrcExtractor.cancelPending();
    VideasyExtractor.cancelPending();
    VidnestExtractor.cancelPending();
    VidsrcsbsExtractor.cancelPending();
    NuvioService.instance.cancelPending();
    if (cancelEngineJobs) {
      // Gen bump + abort flutter_js BEFORE ROOT cancel — otherwise EngineJS
      // "cancelled" maps to null and runPluginIsolated forks JSC mid-play.
      EngineService.instance.abortInFlightExtracts();
      Engine.cancelPendingResolve();
    }
    unawaited(_extractor.cancel());
    for (final extra in List<StreamExtractor>.of(_parallelExtractors)) {
      unawaited(extra.cancel());
    }
    unawaited(KissKhExtractor.cancelAllPending());
  }

  /// Sniff every CFG mirror (bounded concurrency). Nested enc=2 player URLs
  /// use STREAMCRYPTO HTTP; other embeds rotate Servers chips.
  static Future<List<StreamSource>> _sniffVidsrcsbsMirrors({
    required List<VidsrcsbsServer> servers,
    required bool isMovie,
    required String tmdbId,
    required String title,
    required String? year,
    required String? imdbId,
    required int? totalSeasons,
    required int? season,
    required int? episode,
    required String outerEmbed,
    required bool Function() isCancelled,
  }) async {
    if (servers.isEmpty) return const [];

    final hits = <StreamSource>[];
    final sessionExtractors = <StreamExtractor>[];
    var nextIndex = 0;
    var inFlight = 0;
    final done = Completer<void>();

    void finish() {
      if (done.isCompleted) return;
      done.complete();
    }

    void maybeFinish() {
      if (done.isCompleted) return;
      if (isCancelled()) {
        finish();
        return;
      }
      if (nextIndex >= servers.length && inFlight == 0) finish();
    }

    Future<List<StreamSource>?> sniffOne(VidsrcsbsServer server) async {
      if (isCancelled() || done.isCompleted) return null;
      final nested = server.resolveUrl(
        isMovie: isMovie,
        tmdbId: tmdbId,
        season: season,
        episode: episode,
      );
      if (nested.isEmpty || !nested.startsWith('http')) return null;
      if (VideasyExtractor.isStreamCryptoPlayerUrl(nested)) {
        debugPrint('[vidsrcsbs] STREAMCRYPTO ${server.name}: $nested');
        final sniffed = await VideasyExtractor(onLog: debugPrint).extract(
          tmdbId: tmdbId,
          isMovie: isMovie,
          title: title,
          year: year,
          imdbId: imdbId,
          season: season,
          episode: episode,
          totalSeasons: totalSeasons,
          isCancelled: () => isCancelled() || done.isCompleted,
        );
        if (sniffed == null || sniffed.url.isEmpty) return null;
        return _relabelVidsrcsbsSources(
          sniffed: sniffed,
          server: server,
        );
      }
      if (isAndroidTvHeadlessWebViewBlocked) return null;
      debugPrint('[vidsrcsbs] sniffing ${server.name}: $nested');
      final extractor = StreamExtractor();
      sessionExtractors.add(extractor);
      _parallelExtractors.add(extractor);
      try {
        final sniffed = await extractor.extract(
          nested,
          profile: vidsrcsbsNestedExtractProfile,
          referer: outerEmbed,
          isCancelled: () => isCancelled() || done.isCompleted,
          providerId: 'vidsrcsbs',
        );
        if (sniffed == null || sniffed.url.isEmpty) return null;
        return _relabelVidsrcsbsSources(sniffed: sniffed, server: server);
      } finally {
        sessionExtractors.remove(extractor);
        _parallelExtractors.remove(extractor);
        unawaited(extractor.dispose());
      }
    }

    void pump() {
      while (!isCancelled() &&
          !done.isCompleted &&
          inFlight < _webviewSniffConcurrency &&
          nextIndex < servers.length) {
        final server = servers[nextIndex++];
        inFlight++;
        sniffOne(server)
            .then((batch) {
              inFlight--;
              if (batch != null &&
                  batch.isNotEmpty &&
                  !done.isCompleted) {
                hits.addAll(batch);
              }
              pump();
              maybeFinish();
            })
            .catchError((Object e, StackTrace st) {
              debugPrint('[vidsrcsbs] sniff error: $e\n$st');
              inFlight--;
              pump();
              maybeFinish();
            });
      }
      maybeFinish();
    }

    pump();
    await done.future;
    return hits;
  }

  static List<StreamSource> _relabelVidsrcsbsSources({
    required ExtractedMedia sniffed,
    required VidsrcsbsServer server,
  }) {
    return sniffed.sources
            ?.map(
              (s) => StreamSource(
                url: s.url,
                title: s.title == 'Stream' || s.title.isEmpty
                    ? server.name
                    : s.title.toLowerCase().startsWith(
                        server.name.toLowerCase(),
                      )
                    ? s.title
                    : '${server.name} · ${s.title}',
                type: s.type,
                headers: s.headers,
                providerId: 'vidsrcsbs',
                catalogUrl: s.catalogUrl ?? s.url,
              ),
            )
            .toList() ??
        [
          StreamSource(
            url: sniffed.url,
            title: server.name,
            type: _typeFromUrl(sniffed.url),
            headers: sniffed.headers,
            providerId: 'vidsrcsbs',
            catalogUrl: sniffed.url,
          ),
        ];
  }

  static String _encodeResolveResult({
    required String url,
    List<StreamSource>? sources,
    Map<String, String>? headers,
    String? providerId,
  }) {
    if (sources != null && sources.isNotEmpty) {
      final playable = sources
          .where((s) => !isUnplayableCachedStreamUrl(s.url))
          .toList();
      if (playable.isEmpty) {
        return '[]';
      }
      return jsonEncode(
        playable.map((s) {
          final pid = (s.providerId != null && s.providerId!.isNotEmpty)
              ? s.providerId
              : providerId;
          final catalog = s.catalogUrl;
          return {
            'url': s.url,
            'title': s.title,
            'container': s.type,
            if (s.headers != null) 'headers': s.headers,
            if (pid != null && pid.isNotEmpty) 'providerId': pid,
            if (catalog != null && catalog.isNotEmpty) 'catalogUrl': catalog,
          };
        }).toList(),
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
        if (providerId != null && providerId.isNotEmpty)
          'providerId': providerId,
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
