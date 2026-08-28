// Videasy extractor - mirrors player.videasy.to Servers tab.
//
// Pipeline (api.speedracelight.com - NOT the public videasy.to embed docs):
//   1. Metadata from db.speedracelight.com/3 (same as the player page)
//   2. GET /seed?mediaId=… (cached ~25s; refresh on 401)
//   3. GET /{mirror}/sources-with-title?title&enc=2&seed=…&totalSeasons=…
//   4. Decrypt payload (STREAMCRYPTO - seed + tmdbId): Dart or WebView JS
//      per Settings → Playback → STREAMCRYPTO decrypt
//   5. Parse JSON sources — every responsive mirror becomes a Sources row

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:forja/shared/extractors/core/stream_crypto.dart';
import 'package:forja/shared/playback/provider_runtime_config.dart';
import 'package:http/http.dart' as http;
import 'package:rust/rust.dart';

class VideasyExtractor {
  VideasyExtractor({required this.onLog});

  final void Function(String) onLog;

  static const _apiHostDefault = 'api.speedracelight.com';
  static const _dbHostDefault = 'db.speedracelight.com';
  static const _playerOriginDefault = 'https://player.videasy.to';

  /// Stale remote config still ships wingsdatabase (DNS dead). Prefer live host.
  static const _deadApiHosts = {'api.wingsdatabase.com'};
  static const _deadDbHosts = {'db.wingsdatabase.com'};
  static const _apiHostFallbacks = [
    'api.speedracelight.com',
    'api.wingsdatabase.com',
  ];

  static String? _activeApiHost;

  static String get _apiHost {
    final configured =
        ProviderRuntimeConfig.instance.api('videasyApiHost') ?? _apiHostDefault;
    if (_deadApiHosts.contains(configured)) return _apiHostDefault;
    return _activeApiHost ?? configured;
  }

  static String get _dbHost {
    final configured =
        ProviderRuntimeConfig.instance.api('videasyDbHost') ?? _dbHostDefault;
    if (_deadDbHosts.contains(configured)) return _dbHostDefault;
    return configured;
  }

  static String get _playerOrigin =>
      ProviderRuntimeConfig.instance.api('videasyPlayerOrigin') ??
      _playerOriginDefault;
  // Fail hung mirrors fast - m4uhd/vsrc often stall with 0 bytes while cdn
  // (Yoru) answers in ~100ms.
  static const _fetchTimeout = Duration(seconds: 12);
  static const _slowFetchTimeout = Duration(seconds: 18);
  // Cover full parallel mirror fan-out before HostProviderAdapter sniffs.
  static const _defaultExtractTimeout = Duration(seconds: 60);
  static const _maxInFlight = 4;
  static const _seedTtl = Duration(seconds: 25);

  /// Player Servers tab labels (chip-rotate sniff order).
  static const serverChipLabels = <String>[
    'Yoru',
    'Cypher',
    'Breach',
    'Neon',
    'Vyse',
    'Killjoy',
    'Fade',
    'Omen',
    'Raze',
  ];

  /// Servers tab → API path (player.videasy.to / speedracelight).
  /// Listed order only - every mirror is probed (bounded parallel).
  static const _mirrors = <_VideasyMirror>[
    _VideasyMirror('cdn', displayName: 'Yoru'),
    _VideasyMirror('downloader2', displayName: 'Cypher'),
    _VideasyMirror('m4uhd', slow: true, displayName: 'Breach'),
    _VideasyMirror('vsrc', slow: true, displayName: 'Neon'),
    _VideasyMirror('hdmovie', qualityFilter: 'English', displayName: 'Vyse'),
    _VideasyMirror('meine', language: 'german', displayName: 'Killjoy'),
    _VideasyMirror('hdmovie', qualityFilter: 'Hindi', displayName: 'Fade'),
    _VideasyMirror('lamovie', displayName: 'Omen'),
    _VideasyMirror('superflix', displayName: 'Raze'),
  ];

  static const userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';

  static Map<String, String> get _baseHeaders => {
    'User-Agent': userAgent,
    'Referer': '$_playerOrigin/',
    'Origin': _playerOrigin,
    // Match player axios Accept (CF sometimes treats bare */* differently).
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  static Map<String, String> get _playbackHeaders => {
    'User-Agent': userAgent,
    'Referer': '$_playerOrigin/',
    'Origin': _playerOrigin,
  };

  static var _generation = 0;
  static http.Client? _sharedClient;
  static final Map<String, _CachedSeed> _seedCache = {};

  static void cancelPending() {
    _generation++;
    _sharedClient?.close();
    _sharedClient = null;
    _seedCache.clear();
    _activeApiHost = null;
  }

  Future<ExtractedMedia?> extract({
    required String tmdbId,
    required bool isMovie,
    String? title,
    String? year,
    String? imdbId,
    int? season,
    int? episode,
    int? totalSeasons,
    Duration timeout = _defaultExtractTimeout,
    bool Function()? isCancelled,
  }) async {
    try {
      return await _extract(
        tmdbId: tmdbId,
        isMovie: isMovie,
        title: title,
        year: year,
        imdbId: imdbId,
        season: season,
        episode: episode,
        totalSeasons: totalSeasons,
        isCancelled: isCancelled,
      ).timeout(timeout);
    } on TimeoutException {
      onLog('[Videasy] Extraction timed out after ${timeout.inSeconds}s');
      return null;
    } catch (e, st) {
      onLog('[Videasy] Extraction failed: $e\n$st');
      return null;
    }
  }

  Future<ExtractedMedia?> _extract({
    required String tmdbId,
    required bool isMovie,
    String? title,
    String? year,
    String? imdbId,
    int? season,
    int? episode,
    int? totalSeasons,
    bool Function()? isCancelled,
  }) async {
    final tmdb = int.tryParse(tmdbId);
    if (tmdb == null) {
      onLog('[Videasy] Invalid tmdbId: $tmdbId');
      return null;
    }

    final gen = _generation;
    bool cancelled() =>
        (isCancelled?.call() ?? false) || gen != _generation;

    final decryptMode = await SettingsService().getStreamCryptoDecrypt();
    final useNative =
        decryptMode == SettingsService.streamCryptoDecryptNative;
    _VideasyDecryptHost? crypto;
    if (useNative) {
      onLog('[Videasy] STREAMCRYPTO native decrypt');
    } else {
      crypto = await _VideasyDecryptHost.instance.ensureReady(onLog: onLog);
      if (crypto == null) {
        onLog('[Videasy] decrypt runtime unavailable');
        return null;
      }
    }
    if (cancelled()) {
      onLog('[Videasy] cancelled');
      return null;
    }

    final jobs = await _buildJobs(
      tmdbId: tmdbId,
      isMovie: isMovie,
      title: title,
      year: year,
      imdbId: imdbId,
      season: season,
      episode: episode,
      totalSeasons: totalSeasons,
      gen: gen,
      cancelled: cancelled,
    );
    if (jobs.isEmpty || cancelled()) return null;

    return _collectProviders(
      crypto: crypto,
      tmdbId: tmdbId,
      jobs: jobs,
      gen: gen,
      cancelled: cancelled,
    );
  }

  Future<List<_ProviderJob>> _buildJobs({
    required String tmdbId,
    required bool isMovie,
    required String? title,
    required String? year,
    required String? imdbId,
    required int? season,
    required int? episode,
    required int? totalSeasons,
    required int gen,
    required bool Function() cancelled,
  }) async {
    final resolved = await _resolveParams(
      tmdbId: tmdbId,
      isMovie: isMovie,
      title: title,
      year: year,
      imdbId: imdbId,
      season: season,
      episode: episode,
      totalSeasons: totalSeasons,
      gen: gen,
    );
    if (resolved == null || cancelled()) return [];

    final qp = _sourcesQuery(
      title: resolved.title,
      isMovie: isMovie,
      tmdbId: tmdbId,
      year: resolved.year,
      imdbId: resolved.imdbId,
      season: season,
      episode: episode,
      totalSeasons: resolved.totalSeasons,
    );

    final jobs = <_ProviderJob>[];
    for (final mirror in _mirrors) {
      final query = Map<String, String>.from(qp);
      if (mirror.language != null) {
        query['language'] = mirror.language!;
      }
      jobs.add(
        _ProviderJob(
          provider: mirror.endpoint,
          displayName: mirror.displayName,
          query: query,
          qualityFilter: mirror.qualityFilter,
          slow: mirror.slow,
        ),
      );
    }
    return jobs;
  }

  Future<_VideasyParams?> _resolveParams({
    required String tmdbId,
    required bool isMovie,
    required String? title,
    required String? year,
    required String? imdbId,
    required int? season,
    required int? episode,
    required int? totalSeasons,
    required int gen,
  }) async {
    final wings = await _fetchWingsMetadata(
      tmdbId: tmdbId,
      isMovie: isMovie,
      season: season,
      episode: episode,
      gen: gen,
    );
    if (wings != null) {
      onLog('[Videasy] wings metadata: ${wings.title} (${wings.year})');
      return wings;
    }

    final trimmedTitle = title?.trim() ?? '';
    if (trimmedTitle.isEmpty) {
      onLog('[Videasy] no title (wings DB miss and caller title empty)');
      return null;
    }
    return _VideasyParams(
      title: trimmedTitle,
      year: year?.trim() ?? '',
      imdbId: imdbId?.trim() ?? '',
      totalSeasons: totalSeasons,
    );
  }

  Future<_VideasyParams?> _fetchWingsMetadata({
    required String tmdbId,
    required bool isMovie,
    required int? season,
    required int? episode,
    required int gen,
  }) async {
    try {
      if (isMovie) {
        final uri = Uri.https(_dbHost, '/3/movie/$tmdbId', {
          'append_to_response': 'external_ids',
        });
        final res = await _get(uri, gen: gen);
        if (res.statusCode != 200) return null;
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final name = (data['title'] ?? data['name'] ?? '').toString().trim();
        if (name.isEmpty) return null;
        final release = (data['release_date'] ?? '').toString();
        final year = yearFromReleaseDate(release) ?? '';
        final imdb =
            (data['external_ids'] as Map?)?['imdb_id']?.toString() ?? '';
        return _VideasyParams(title: name, year: year, imdbId: imdb);
      }

      final showUri = Uri.https(_dbHost, '/3/tv/$tmdbId', {
        'append_to_response': 'external_ids',
      });
      final showRes = await _get(showUri, gen: gen);
      if (showRes.statusCode != 200) return null;
      final show = jsonDecode(showRes.body) as Map<String, dynamic>;
      final name = (show['name'] ?? show['title'] ?? '').toString().trim();
      if (name.isEmpty) return null;

      final seasons = (show['seasons'] as List?) ?? const [];
      const specials = {'Specials', 'Especiais', 'Especiales'};
      final counted = seasons.where((s) {
        if (s is! Map) return false;
        final n = s['season_number'];
        if (n is num && n <= 0) return false;
        final label = (s['name'] ?? '').toString();
        return !specials.contains(label);
      }).length;

      final release = (show['first_air_date'] ?? '').toString();
      final imdb = (show['external_ids'] as Map?)?['imdb_id']?.toString() ?? '';

      return _VideasyParams(
        title: name,
        year: yearFromReleaseDate(release) ?? '',
        imdbId: imdb,
        totalSeasons: counted > 0 ? counted : null,
      );
    } catch (e) {
      onLog('[Videasy] wings metadata fetch failed: $e');
      return null;
    }
  }

  static Map<String, String> _sourcesQuery({
    required String title,
    required bool isMovie,
    required String tmdbId,
    required String year,
    required String imdbId,
    required int? season,
    required int? episode,
    required int? totalSeasons,
  }) {
    // Player always sends seasonId/episodeId (defaults to 1 even for movies).
    final qp = <String, String>{
      'title': wingsTitleQueryValue(title),
      'mediaType': isMovie ? 'movie' : 'tv',
      'tmdbId': tmdbId,
      'seasonId': '${season ?? 1}',
      'episodeId': '${episode ?? 1}',
    };
    if (year.length >= 4) qp['year'] = year.substring(0, 4);
    if (imdbId.isNotEmpty) qp['imdbId'] = imdbId;
    if (!isMovie && totalSeasons != null && totalSeasons > 0) {
      qp['totalSeasons'] = '$totalSeasons';
    }
    return qp;
  }

  Future<String?> _getSeed(
    String tmdbId, {
    required int gen,
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    if (!forceRefresh) {
      final cached = _seedCache[tmdbId];
      if (cached != null &&
          cached.expiresAt.isAfter(now.add(const Duration(seconds: 5)))) {
        return cached.seed;
      }
    } else {
      _seedCache.remove(tmdbId);
    }

    final configured =
        ProviderRuntimeConfig.instance.api('videasyApiHost') ?? _apiHostDefault;
    final hosts = <String>[
      ?_activeApiHost,
      if (!_deadApiHosts.contains(configured)) configured,
      ..._apiHostFallbacks,
    ];
    final seen = <String>{};
    for (final host in hosts) {
      if (!seen.add(host)) continue;
      if (gen != _generation) return null;
      try {
        final uri = Uri.https(host, '/seed', {'mediaId': tmdbId});
        final res = await _get(uri, gen: gen);
        if (res.statusCode != 200) {
          onLog('[Videasy] seed $host -> ${res.statusCode}');
          // Keep last good seed - 429 mid-fanout must not kill remaining probes.
          if (res.statusCode == 429) return _seedCache[tmdbId]?.seed;
          continue;
        }
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final seed = data['seed']?.toString().trim();
        if (seed == null || seed.isEmpty) continue;
        final ttlMs = (data['ttlMs'] as num?)?.toInt();
        final ttl = ttlMs != null && ttlMs > 0
            ? Duration(milliseconds: ttlMs)
            : _seedTtl;
        _seedCache[tmdbId] = _CachedSeed(seed: seed, expiresAt: now.add(ttl));
        _activeApiHost = host;
        if (host != configured) {
          onLog('[Videasy] seed host failover → $host');
        }
        return seed;
      } catch (e) {
        onLog('[Videasy] seed fetch failed ($host): $e');
      }
    }
    return _seedCache[tmdbId]?.seed;
  }

  static void _invalidateSeed(String tmdbId) => _seedCache.remove(tmdbId);

  /// Probe every mirror (bounded parallel). Sources lists each responsive
  /// server — do not abort the queue after the first hit.
  Future<ExtractedMedia?> _collectProviders({
    required _VideasyDecryptHost? crypto,
    required String tmdbId,
    required List<_ProviderJob> jobs,
    required int gen,
    required bool Function() cancelled,
  }) async {
    final hits = <ExtractedMedia>[];
    var nextIndex = 0;
    var inFlight = 0;
    final done = Completer<void>();

    void finish() {
      if (done.isCompleted) return;
      done.complete();
    }

    void maybeFinish() {
      if (done.isCompleted) return;
      if (cancelled()) {
        finish();
        return;
      }
      if (nextIndex >= jobs.length && inFlight == 0) finish();
    }

    void pump() {
      while (!cancelled() &&
          !done.isCompleted &&
          inFlight < _maxInFlight &&
          nextIndex < jobs.length) {
        final job = jobs[nextIndex++];
        inFlight++;
        _probeProvider(crypto: crypto, tmdbId: tmdbId, job: job, gen: gen)
            .then((hit) {
              inFlight--;
              if (hit != null && !done.isCompleted) {
                hits.add(hit);
              }
              pump();
              maybeFinish();
            })
            .catchError((Object e, StackTrace st) {
              onLog('[Videasy] ${job.provider} probe error: $e\n$st');
              inFlight--;
              pump();
              maybeFinish();
            });
      }
      maybeFinish();
    }

    pump();
    await done.future;

    if (hits.isEmpty) {
      if (!cancelled()) onLog('[Videasy] No sources from any mirror');
      return null;
    }

    final allSources = <StreamSource>[];
    final allSubs = <Map<String, dynamic>>[];
    for (final hit in hits) {
      final srcs = hit.sources ?? const <StreamSource>[];
      allSources.addAll(srcs);
      final subs = hit.externalSubtitles;
      if (subs == null) continue;
      for (final sub in subs) {
        final url = sub['url']?.toString() ?? '';
        if (url.isEmpty) continue;
        if (allSubs.any((e) => e['url'] == url)) continue;
        allSubs.add(sub);
      }
    }
    if (allSources.isEmpty) return null;

    final primary = allSources.first;
    onLog('[Videasy] ${hits.length} mirror(s) → ${allSources.length} sources');
    return ExtractedMedia(
      url: primary.url,
      headers: _playbackHeaders,
      sources: allSources,
      provider: hits.first.provider ?? 'videasy',
      externalSubtitles: allSubs.isEmpty ? null : allSubs,
    );
  }

  Future<ExtractedMedia?> _probeProvider({
    required _VideasyDecryptHost? crypto,
    required String tmdbId,
    required _ProviderJob job,
    required int gen,
  }) async {
    if (gen != _generation) return null;

    final timeout = job.slow ? _slowFetchTimeout : _fetchTimeout;

    for (var attempt = 0; attempt < 2; attempt++) {
      if (gen != _generation) return null;

      final seed = await _getSeed(tmdbId, gen: gen, forceRefresh: attempt > 0);
      if (seed == null) return null;

      final uri = Uri.https(_apiHost, '/${job.provider}/sources-with-title', {
        ...job.query,
        'enc': '2',
        'seed': seed,
      });
      onLog('[Videasy] GET $uri');

      http.Response res;
      try {
        res = await _get(uri, gen: gen, timeout: timeout);
      } catch (e) {
        onLog('[Videasy] ${job.provider} fetch error: $e');
        return null;
      }
      if (gen != _generation) return null;

      final body = res.body.trim();
      final seedInvalid =
          res.statusCode == 401 || body.contains('STREAMCRYPTO_SEED_INVALID');
      if (seedInvalid && attempt == 0) {
        onLog('[Videasy] ${job.provider} seed invalid - retrying');
        _invalidateSeed(tmdbId);
        continue;
      }

      if (res.statusCode != 200 || body.length < 50) {
        onLog(
          '[Videasy] ${job.provider} -> ${res.statusCode} '
          '(${body.length} bytes), skip',
        );
        return null;
      }
      if (body.startsWith('{') || body.startsWith('<')) {
        onLog('[Videasy] ${job.provider} -> error payload, skip');
        return null;
      }

      String json;
      try {
        json = await _decryptPayload(
          body: body,
          seed: seed,
          tmdbId: tmdbId,
          crypto: crypto,
        );
      } catch (e) {
        onLog('[Videasy] ${job.provider} decrypt error: $e');
        return null;
      }
      if (gen != _generation) return null;

      Map<String, dynamic> data;
      try {
        data = jsonDecode(json) as Map<String, dynamic>;
      } catch (e) {
        onLog('[Videasy] ${job.provider} JSON parse error: $e');
        return null;
      }

      final parsed = _parsePayload(
        data,
        job.provider,
        displayName: job.displayName,
        qualityFilter: job.qualityFilter,
      );
      if (parsed == null) return null;

      onLog(
        '[Videasy] ${job.displayName} (${job.provider}) -> '
        '${parsed.sources?.length ?? 0} sources, '
        '${parsed.externalSubtitles?.length ?? 0} subs',
      );
      return parsed;
    }

    return null;
  }

  ExtractedMedia? _parsePayload(
    Map<String, dynamic> data,
    String provider, {
    required String displayName,
    String? qualityFilter,
  }) {
    final srcs = (data['sources'] as List?) ?? const [];
    final subs = (data['subtitles'] as List?) ?? const [];
    if (srcs.isEmpty) return null;

    final sources = <StreamSource>[];
    final dash = <StreamSource>[];
    final nonDash = <StreamSource>[];

    for (final s in srcs) {
      if (s is! Map) continue;
      final rawUrl = (s['url'] ?? s['file'] ?? '').toString();
      if (rawUrl.isEmpty) continue;
      final url = preferHlsMasterUrl(rawUrl);
      final quality = (s['quality'] ?? s['label'] ?? s['title'] ?? 'auto')
          .toString();
      if (qualityFilter != null && quality != qualityFilter) continue;

      final type = (s['type'] ?? (url.contains('.m3u8') ? 'hls' : 'video'))
          .toString();
      final isDash = type == 'dash' || url.toLowerCase().contains('.mpd');
      final source = StreamSource(
        url: url,
        title: '$displayName · $quality',
        type: type,
        headers: _playbackHeaders,
        providerId: 'videasy',
        catalogUrl: url,
      );
      sources.add(source);
      if (isDash) {
        dash.add(source);
      } else {
        nonDash.add(source);
      }
    }

    // Neon (vsrc / legacy neon2): player prefers DASH when present.
    final preferDash = provider == 'vsrc' || provider == 'neon2';
    final picked = preferDash && dash.isNotEmpty ? dash : sources;
    if (picked.isEmpty) return null;

    final allSubs = <Map<String, dynamic>>[];
    for (final sub in subs) {
      if (sub is! Map) continue;
      final url = (sub['url'] ?? sub['file'] ?? '').toString();
      if (url.isEmpty) continue;
      if (allSubs.any((e) => e['url'] == url)) continue;
      final lang = (sub['lang'] ?? sub['language'] ?? sub['label'] ?? 'Unknown')
          .toString();
      final label = (sub['label'] ?? sub['title'] ?? lang).toString();
      allSubs.add({
        'url': url,
        'language': lang,
        'display': '$label - videasy/$displayName',
      });
    }

    picked.sort((a, b) => _qualityRank(b.title) - _qualityRank(a.title));
    return ExtractedMedia(
      url: picked.first.url,
      headers: _playbackHeaders,
      sources: picked,
      provider: 'videasy/$provider',
      externalSubtitles: allSubs.isEmpty ? null : allSubs,
    );
  }

  Future<http.Response> _get(
    Uri uri, {
    required int gen,
    Duration timeout = _fetchTimeout,
  }) async {
    if (gen != _generation) throw StateError('cancelled');
    _sharedClient ??= http.Client();
    final res = await _sharedClient!
        .get(uri, headers: _baseHeaders)
        .timeout(timeout);
    if (gen != _generation) throw StateError('cancelled');
    return res;
  }

  /// Single-encoded title for [Uri.https]; builder adds second pass (`%2520`).
  static String wingsTitleQueryValue(String title) =>
      Uri.encodeComponent(title);

  /// API often returns demuxed media playlists; open the sibling master instead.
  @visibleForTesting
  static String preferHlsMasterUrl(String url) {
    final u = url.trim();
    if (!RegExp(r'index-s\d+p-v\d+-a\d+\.m3u8', caseSensitive: false)
        .hasMatch(u)) {
      return u;
    }
    final withSd = u.replaceFirst(
      RegExp(r'/sd/\d+/index-s\d+p-v\d+-a\d+\.m3u8', caseSensitive: false),
      '/master.m3u8',
    );
    if (withSd != u) return withSd;
    return u.replaceFirst(
      RegExp(r'/index-s\d+p-v\d+-a\d+\.m3u8', caseSensitive: false),
      '/master.m3u8',
    );
  }

  @visibleForTesting
  static List<String> mirrorEndpointsForTest() => [
    for (final m in _mirrors) m.endpoint,
  ];

  @visibleForTesting
  static List<String> mirrorDisplayNamesForTest() => [
    for (final m in _mirrors) m.displayName,
  ];

  @visibleForTesting
  static Map<String, String> sourcesQueryForTest({
    required String title,
    required bool isMovie,
    required String tmdbId,
    required String year,
    required String imdbId,
    required int season,
    required int episode,
    required int? totalSeasons,
    required String seed,
  }) {
    return {
      ..._sourcesQuery(
        title: title,
        isMovie: isMovie,
        tmdbId: tmdbId,
        year: year,
        imdbId: imdbId,
        season: season,
        episode: episode,
        totalSeasons: totalSeasons,
      ),
      'enc': '2',
      'seed': seed,
    };
  }

  /// enc=2 player embed (Videasy provider, VidSrc.sbs 4K nested, …).
  static bool isStreamCryptoPlayerUrl(String url) => StreamCrypto.isPlayerUrl(
    url,
    configuredOrigin: ProviderRuntimeConfig.instance.api('videasyPlayerOrigin'),
  );

  static String? yearFromReleaseDate(String? releaseDate) {
    final value = releaseDate?.trim() ?? '';
    if (value.length < 4) return null;
    return value.substring(0, 4);
  }

  static int _qualityRank(String title) {
    final t = title.toLowerCase();
    if (t.contains('2160') || t.contains('4k')) return 4;
    if (t.contains('1080')) return 3;
    if (t.contains('720')) return 2;
    if (t.contains('480')) return 1;
    return 0;
  }

  Future<String> _decryptPayload({
    required String body,
    required String seed,
    required String tmdbId,
    required _VideasyDecryptHost? crypto,
  }) async {
    if (crypto == null) {
      return StreamCrypto.decrypt(body, seed, tmdbId);
    }
    return crypto.decrypt(body, seed, tmdbId);
  }
}

class _VideasyParams {
  const _VideasyParams({
    required this.title,
    required this.year,
    required this.imdbId,
    this.totalSeasons,
  });

  final String title;
  final String year;
  final String imdbId;
  final int? totalSeasons;
}

class _CachedSeed {
  const _CachedSeed({required this.seed, required this.expiresAt});

  final String seed;
  final DateTime expiresAt;
}

class _VideasyMirror {
  const _VideasyMirror(
    this.endpoint, {
    required this.displayName,
    this.qualityFilter,
    this.language,
    this.slow = false,
  });

  final String endpoint;
  final String displayName;
  final String? qualityFilter;
  final String? language;
  final bool slow;
}

class _ProviderJob {
  const _ProviderJob({
    required this.provider,
    required this.displayName,
    required this.query,
    this.qualityFilter,
    this.slow = false,
  });

  final String provider;
  final String displayName;
  final Map<String, String> query;
  final String? qualityFilter;
  final bool slow;
}

/// WebView STREAMCRYPTO runtime (enc=2 player family — not Videasy-only).
class _VideasyDecryptHost {
  _VideasyDecryptHost._();
  static final _VideasyDecryptHost instance = _VideasyDecryptHost._();

  HeadlessInAppWebView? _hw;
  InAppWebViewController? _controller;
  Completer<bool>? _ready;

  static const _decryptJs = r'''
(function(){
  var f=[1116352408,1899447441,3049323471,3921009573,961987163,1508970993,2453635748,2870763221,3624381080,310598401,607225278,1426881987,1925078388,2162078206,2614888103,3248222580];
  var b=[109,118,109,49];
  var h=function(e){return(e*(e+1)&1)==0};
  var I=function(e){return(e*(e+1)&1)==1};
  function w(e){e>>>=0;e^=e>>>16;e=Math.imul(e,2246822507)>>>0;e^=e>>>13;e=Math.imul(e,3266489909)>>>0;return(e^=e>>>16)>>>0}
  function v(e,t){e>>>=0;return(t&=31)===0?e>>>0:(e<<t|e>>>32-t)>>>0}
  window.videasy_decrypt_payload=function(e,t,s){
    var o=(function(e){var t=e.replace(/-/g,"+").replace(/_/g,"/").padEnd(4*Math.ceil(e.length/4),"=");var bin=atob(t),out=new Uint8Array(bin.length);for(var i=0;i<bin.length;i++)out[i]=bin.charCodeAt(i);return out})(e);
    var r=(function(e,t,s){var a=(function(e,t){if(I(e.length))return{S:(function(e){var t=Array(256);for(var i=0;i<256;i++)t[i]=i;var s=0;for(var a=0;a<256;a++){s=s+t[a]+e.charCodeAt(a%e.length)&255;var o=t[a];t[a]=t[s];t[s]=o}return t})(e),acc:(function(e){var t=1732584193;for(var s=0;s<e.length;s++)t=v((t^Math.imul(e.charCodeAt(s),f[15&s]))>>>0,5);return w(t)})(e)};var s=Array(61),a=w((function(e){var t=2166136261;for(var s=0;s<e.length;s++)t=Math.imul(t^e.charCodeAt(s),16777619)>>>0;return w(t)})(e)^w((t>>>0)^2654435769))>>>0;for(var e=0;e<8;e++)if(h(e)){var t=a%61;a=v(a+2654435769>>>0,7+(7&e));s[t]=(a^w(a))>>>0;a=w(a+t>>>0)}else s[e]=f[15&e];return{S:s,acc:w(2779096485^a)>>>0}})(e,t),o=new Uint8Array(s),r=0;for(var e=0;e<s;){var t=(function(e,t){var o=e.S,r=e.acc,n=r%61,i=0-Number(n in o),d=o[n]>>>0,l=((r^(d^Math.imul(2654435769,t+1)>>>0)>>>0)|(r&(d^Math.imul(2654435769,t+1)>>>0)&i)>>>0)>>>0;r=w((l=(v(l+r>>>0,31&n)^v(r,31&Math.imul(n,7)))>>>0)+2654435769>>>0);o[n]=r>>>0;e.acc=r;return r>>>0})(a,r++);o[e++]=255&t;e<s&&(o[e++]=t>>>8&255);e<s&&(o[e++]=t>>>16&255);e<s&&(o[e++]=t>>>24&255)}return o})(t,s,o.length);
    for(var i=0;i<o.length;i++)o[i]^=r[i];
    for(var j=0;j<b.length;j++)if(o[j]!==b[j])throw new Error('decrypt failed');
    var pt=o.subarray(b.length);
    return new TextDecoder('utf-8').decode(pt);
  };
})();
''';

  Future<_VideasyDecryptHost?> ensureReady({
    required void Function(String) onLog,
  }) async {
    if (_ready != null) {
      final ok = await _ready!.future;
      return ok ? this : null;
    }
    if (SettingsService.platformProfile == PlatformProfile.androidTv &&
        !SettingsService.allowAndroidTvHeadlessWebViewExtractors) {
      onLog('[Videasy] decrypt WebView blocked on Android TV');
      _ready = Completer<bool>()..complete(false);
      return null;
    }
    _ready = Completer<bool>();

    try {
      final html =
          '<!doctype html><html><head><meta charset="utf-8"></head><body><script>$_decryptJs</script></body></html>';
      final completer = Completer<void>();
      _hw = HeadlessInAppWebView(
        initialData: InAppWebViewInitialData(
          data: html,
          mimeType: 'text/html',
          encoding: 'utf-8',
          baseUrl: WebUri('https://player.videasy.to'),
        ),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          userAgent: VideasyExtractor.userAgent,
        ),
        onLoadStop: (c, _) {
          _controller = c;
          if (!completer.isCompleted) completer.complete();
        },
        onConsoleMessage: (_, msg) {
          onLog('[Videasy/decrypt-console] ${msg.message}');
        },
      );
      await _hw!.run();
      await completer.future.timeout(const Duration(seconds: 15));
      onLog('[Videasy] decrypt runtime ready');
      _ready!.complete(true);
      return this;
    } catch (e, st) {
      onLog('[Videasy] decrypt bootstrap failed: $e\n$st');
      if (!_ready!.isCompleted) _ready!.complete(false);
      return null;
    }
  }

  Future<String> decrypt(String payload, String seed, String mediaId) async {
    final c = _controller;
    if (c == null) throw StateError('decrypt controller not initialized');
    final res = await c.callAsyncJavaScript(
      functionBody:
          'return window.videasy_decrypt_payload(payload, seed, mediaId);',
      arguments: {'payload': payload, 'seed': seed, 'mediaId': mediaId},
    );
    if (res?.error != null) throw Exception('JS: ${res!.error}');
    final v = res?.value;
    if (v is! String || v.isEmpty) {
      throw Exception('empty decrypt result (${v.runtimeType})');
    }
    return v;
  }
}
