// Videasy extractor — mirrors player.videasy.to (see videasy chunk 8351).
//
// Pipeline (api.wingsdatabase.com only — NOT api.videasy.net):
//   1. GET /seed?mediaId=…
//   2. GET /{mirror}/sources-with-title?title&enc=2&seed=…&totalSeasons=…
//   3. Decrypt payload in headless WebView (STREAMCRYPTO — seed + tmdbId)
//   4. Parse JSON sources

import 'dart:async';
import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:rust/rust.dart';

import 'extracted_media.dart';

class VideasyExtractor {
  VideasyExtractor({required this.onLog});

  final void Function(String) onLog;

  static const _apiHost = 'api.wingsdatabase.com';
  static const _playerOrigin = 'https://player.videasy.to';
  static const _fetchTimeout = Duration(seconds: 15);
  static const _defaultExtractTimeout = Duration(seconds: 30);
  static const _maxInFlight = 4;

  /// Mirrors from the live player (Neon, Sage, Jett, Breach, Vyse, Yoru, Raze).
  static const _mirrors = <_VideasyMirror>[
    _VideasyMirror('neon2'),
    _VideasyMirror('ym'),
    _VideasyMirror('jett'),
    _VideasyMirror('m4uhd'),
    _VideasyMirror('hdmovie', englishOnly: true),
    _VideasyMirror('superflix'),
    _VideasyMirror('cdn', movieOnly: true),
  ];

  static const userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';

  static const _baseHeaders = <String, String>{
    'User-Agent': userAgent,
    'Referer': '$_playerOrigin/',
    'Origin': _playerOrigin,
    'Accept': '*/*',
  };

  static const _playbackHeaders = <String, String>{
    'User-Agent': userAgent,
    'Referer': '$_playerOrigin/',
    'Origin': _playerOrigin,
  };

  static var _generation = 0;
  static http.Client? _sharedClient;

  static void cancelPending() {
    _generation++;
    _sharedClient?.close();
    _sharedClient = null;
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
    final cancelled = () =>
        (isCancelled?.call() ?? false) || gen != _generation;

    final crypto = await _VideasyDecryptHost.instance.ensureReady(onLog: onLog);
    if (crypto == null) {
      onLog('[Videasy] decrypt runtime unavailable');
      return null;
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

    return _raceProviders(
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
    final trimmedTitle = title?.trim() ?? '';
    if (trimmedTitle.isEmpty) return [];

    final seed = await _fetchSeed(tmdbId, gen: gen);
    if (seed == null || cancelled()) return [];

    final qp = _sourcesQuery(
      title: trimmedTitle,
      isMovie: isMovie,
      tmdbId: tmdbId,
      year: year?.trim() ?? '',
      imdbId: imdbId?.trim() ?? '',
      season: season,
      episode: episode,
      totalSeasons: totalSeasons,
      seed: seed,
    );

    final jobs = <_ProviderJob>[];
    for (final mirror in _mirrors) {
      if (mirror.movieOnly && !isMovie) continue;
      jobs.add(
        _ProviderJob(
          provider: mirror.endpoint,
          query: Map<String, String>.from(qp),
          englishOnly: mirror.englishOnly,
        ),
      );
    }
    return jobs;
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
    required String seed,
  }) {
    final qp = <String, String>{
      'title': wingsTitleQueryValue(title),
      'mediaType': isMovie ? 'movie' : 'tv',
      'tmdbId': tmdbId,
      'enc': '2',
      'seed': seed,
    };
    if (year.length >= 4) qp['year'] = year.substring(0, 4);
    if (imdbId.isNotEmpty) qp['imdbId'] = imdbId;
    if (!isMovie) {
      qp['seasonId'] = '${season ?? 1}';
      qp['episodeId'] = '${episode ?? 1}';
      if (totalSeasons != null && totalSeasons > 0) {
        qp['totalSeasons'] = '$totalSeasons';
      }
    }
    return qp;
  }

  Future<String?> _fetchSeed(String tmdbId, {required int gen}) async {
    try {
      final uri = Uri.https(_apiHost, '/seed', {'mediaId': tmdbId});
      final res = await _get(uri, gen: gen);
      if (res.statusCode != 200) {
        onLog('[Videasy] seed -> ${res.statusCode}');
        return null;
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final seed = data['seed']?.toString().trim();
      return seed == null || seed.isEmpty ? null : seed;
    } catch (e) {
      onLog('[Videasy] seed fetch failed: $e');
      return null;
    }
  }

  Future<ExtractedMedia?> _raceProviders({
    required _VideasyDecryptHost crypto,
    required String tmdbId,
    required List<_ProviderJob> jobs,
    required int gen,
    required bool Function() cancelled,
  }) async {
    final completer = Completer<ExtractedMedia?>();
    var settled = 0;
    var inFlight = 0;
    var nextIndex = 0;
    var stopLaunching = false;

    void finish(ExtractedMedia? hit) {
      if (completer.isCompleted) return;
      if (hit != null) {
        _stopInFlightRequests(gen);
        completer.complete(hit);
        return;
      }
      if (settled >= jobs.length) completer.complete(null);
    }

    void pump() {
      while (!cancelled() &&
          !stopLaunching &&
          inFlight < _maxInFlight &&
          nextIndex < jobs.length) {
        final job = jobs[nextIndex++];
        inFlight++;
        _probeProvider(crypto: crypto, tmdbId: tmdbId, job: job, gen: gen)
            .then((hit) {
          settled++;
          inFlight--;
          if (hit != null) {
            stopLaunching = true;
            finish(hit);
          } else if (settled >= jobs.length) {
            finish(null);
          }
          pump();
        }).catchError((Object e, StackTrace st) {
          onLog('[Videasy] ${job.provider} probe error: $e\n$st');
          settled++;
          inFlight--;
          if (settled >= jobs.length) finish(null);
          pump();
        });
      }
      if (nextIndex >= jobs.length && inFlight == 0 && !completer.isCompleted) {
        finish(null);
      }
    }

    pump();
    return completer.future;
  }

  void _stopInFlightRequests(int gen) {
    if (gen == _generation) _generation++;
    _sharedClient?.close();
    _sharedClient = null;
  }

  Future<ExtractedMedia?> _probeProvider({
    required _VideasyDecryptHost crypto,
    required String tmdbId,
    required _ProviderJob job,
    required int gen,
  }) async {
    if (gen != _generation) return null;

    final uri = Uri.https(
      _apiHost,
      '/${job.provider}/sources-with-title',
      job.query,
    );
    onLog('[Videasy] GET $uri');

    http.Response res;
    try {
      res = await _get(uri, gen: gen);
    } catch (e) {
      onLog('[Videasy] ${job.provider} fetch error: $e');
      return null;
    }
    if (gen != _generation) return null;

    final body = res.body.trim();
    if (res.statusCode != 200 || body.length < 50) {
      onLog('[Videasy] ${job.provider} -> ${res.statusCode} '
          '(${body.length} bytes), skip');
      return null;
    }
    if (body.startsWith('{') || body.startsWith('<')) {
      onLog('[Videasy] ${job.provider} -> error payload, skip');
      return null;
    }

    final seed = job.query['seed'];
    if (seed == null) return null;

    String json;
    try {
      json = await crypto.decrypt(body, seed, tmdbId);
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
      englishOnly: job.englishOnly,
    );
    if (parsed == null) return null;

    onLog('[Videasy] ${job.provider} -> ${parsed.sources?.length ?? 0} sources, '
        '${parsed.externalSubtitles?.length ?? 0} subs');
    return parsed;
  }

  ExtractedMedia? _parsePayload(
    Map<String, dynamic> data,
    String provider, {
    bool englishOnly = false,
  }) {
    final srcs = (data['sources'] as List?) ?? const [];
    final subs = (data['subtitles'] as List?) ?? const [];
    if (srcs.isEmpty) return null;

    final sources = <StreamSource>[];
    final nonDash = <StreamSource>[];

    for (final s in srcs) {
      if (s is! Map) continue;
      final url = (s['url'] ?? s['file'] ?? '').toString();
      if (url.isEmpty) continue;
      final quality =
          (s['quality'] ?? s['label'] ?? s['title'] ?? 'auto').toString();
      if (englishOnly && quality != 'English') continue;

      final type = (s['type'] ?? (url.contains('.m3u8') ? 'hls' : 'video'))
          .toString();
      final isDash = type == 'dash' ||
          url.toLowerCase().contains('.mpd');
      final source = StreamSource(
        url: url,
        title: '$provider · $quality',
        type: type,
        headers: _playbackHeaders,
      );
      sources.add(source);
      if (!isDash) nonDash.add(source);
    }

    final picked = provider == 'neon2' && nonDash.isNotEmpty ? nonDash : sources;
    if (picked.isEmpty) return null;

    final allSubs = <Map<String, dynamic>>[];
    for (final sub in subs) {
      if (sub is! Map) continue;
      final url = (sub['url'] ?? sub['file'] ?? '').toString();
      if (url.isEmpty) continue;
      if (allSubs.any((e) => e['url'] == url)) continue;
      final lang =
          (sub['lang'] ?? sub['language'] ?? sub['label'] ?? 'Unknown')
              .toString();
      final label = (sub['label'] ?? sub['title'] ?? lang).toString();
      allSubs.add({
        'url': url,
        'language': lang,
        'display': '$label - videasy/$provider',
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

  Future<http.Response> _get(Uri uri, {required int gen}) async {
    if (gen != _generation) throw StateError('cancelled');
    _sharedClient ??= http.Client();
    final res = await _sharedClient!
        .get(uri, headers: _baseHeaders)
        .timeout(_fetchTimeout);
    if (gen != _generation) throw StateError('cancelled');
    return res;
  }

  /// Single-encoded title for [Uri.https]; builder adds second pass (`%2520`).
  static String wingsTitleQueryValue(String title) =>
      Uri.encodeComponent(title);

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
}

class _VideasyMirror {
  const _VideasyMirror(
    this.endpoint, {
    this.movieOnly = false,
    this.englishOnly = false,
  });

  final String endpoint;
  final bool movieOnly;
  final bool englishOnly;
}

class _ProviderJob {
  const _ProviderJob({
    required this.provider,
    required this.query,
    this.englishOnly = false,
  });

  final String provider;
  final Map<String, String> query;
  final bool englishOnly;
}

/// Hosts the STREAMCRYPTO decrypt routine from player.videasy.to.
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

  Future<_VideasyDecryptHost?> ensureReady(
      {required void Function(String) onLog}) async {
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
      arguments: {
        'payload': payload,
        'seed': seed,
        'mediaId': mediaId,
      },
    );
    if (res?.error != null) throw Exception('JS: ${res!.error}');
    final v = res?.value;
    if (v is! String || v.isEmpty) {
      throw Exception('empty decrypt result (${v.runtimeType})');
    }
    return v;
  }
}
