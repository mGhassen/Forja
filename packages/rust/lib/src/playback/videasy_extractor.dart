// Pure-Dart Videasy extractor (no page scraping).
//
// Pipeline:
//   1. Optional seed from https://api.wingsdatabase.com/seed?mediaId=…
//   2. HTTP GET sources-with-title from wingsdatabase (enc=2 + title/year)
//      or legacy https://api.videasy.net/{provider}/sources-with-title?tmdbId=…
//      -> hex-encoded blob (~9000 chars).
//   3. Run blob through bundled patched WASM `decrypt(blob, tmdbId)`.
//   4. Rust AES decrypt (OpenSSL salted) -> JSON sources.
//
// Sub-providers are raced with limited concurrency; the first hit wins so play
// start is not blocked harvesting every mirror.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:rust/rust.dart';

import 'extracted_media.dart';

class VideasyExtractor {
  VideasyExtractor({required this.onLog});

  final void Function(String) onLog;

  static const _playerOrigin = 'https://player.videasy.to';
  static const _fetchTimeout = Duration(seconds: 5);
  static const _defaultExtractTimeout = Duration(seconds: 20);
  static const _maxInFlight = 2;

  static const _wingsHost = 'api.wingsdatabase.com';
  static const _legacyHost = 'api.videasy.net';

  static const _wingsProviders = <String>[
    'jett',
    'cdn',
    'yoru',
    'tejo',
    'neon2',
  ];

  static const _legacyProviders = <String>[
    'cdn',
    'myflixerzupcloud',
    'mb-flix',
    '1movies',
    'moviebox',
    'primesrcme',
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

    final wasm = await _VideasyWasm.instance.ensureReady(onLog: onLog);
    if (wasm == null) {
      onLog('[Videasy] WASM runtime unavailable');
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
      gen: gen,
      cancelled: cancelled,
    );
    if (jobs.isEmpty || cancelled()) return null;

    return _raceProviders(
      wasm: wasm,
      tmdb: tmdb,
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
    required int gen,
    required bool Function() cancelled,
  }) async {
    final jobs = <_ProviderJob>[];

    final trimmedTitle = title?.trim() ?? '';
    final trimmedYear = year?.trim() ?? '';
    final trimmedImdb = imdbId?.trim() ?? '';

    if (trimmedTitle.isNotEmpty) {
      final seed = await _fetchSeed(tmdbId, gen: gen);
      if (seed != null && !cancelled()) {
        final qp = <String, String>{
          'title': doubleEncodeTitle(trimmedTitle),
          'mediaType': isMovie ? 'movie' : 'tv',
          'tmdbId': tmdbId,
          'enc': '2',
          'seed': seed,
        };
        if (trimmedYear.length >= 4) qp['year'] = trimmedYear.substring(0, 4);
        if (trimmedImdb.isNotEmpty) qp['imdbId'] = trimmedImdb;
        if (!isMovie) {
          qp['seasonId'] = '${season ?? 1}';
          qp['episodeId'] = '${episode ?? 1}';
        }
        for (final provider in _wingsProviders) {
          jobs.add(
            _ProviderJob(
              host: _wingsHost,
              provider: provider,
              query: Map<String, String>.from(qp),
            ),
          );
        }
      }
    }

    final legacyQp = <String, String>{
      'tmdbId': tmdbId,
      'mediaType': isMovie ? 'movie' : 'tv',
    };
    if (!isMovie) {
      legacyQp['seasonId'] = '${season ?? 1}';
      legacyQp['episodeId'] = '${episode ?? 1}';
    }
    for (final provider in _legacyProviders) {
      jobs.add(
        _ProviderJob(
          host: _legacyHost,
          provider: provider,
          query: Map<String, String>.from(legacyQp),
        ),
      );
    }

    return jobs;
  }

  Future<String?> _fetchSeed(String tmdbId, {required int gen}) async {
    try {
      final uri = Uri.https(_wingsHost, '/seed', {'mediaId': tmdbId});
      final res = await _get(uri, gen: gen);
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final seed = data['seed']?.toString().trim();
      return seed == null || seed.isEmpty ? null : seed;
    } catch (e) {
      onLog('[Videasy] seed fetch skipped: $e');
      return null;
    }
  }

  Future<ExtractedMedia?> _raceProviders({
    required _VideasyWasm wasm,
    required int tmdb,
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
      if (settled >= jobs.length) {
        completer.complete(null);
      }
    }

    void pump() {
      while (!cancelled() &&
          !stopLaunching &&
          inFlight < _maxInFlight &&
          nextIndex < jobs.length) {
        final job = jobs[nextIndex++];
        inFlight++;
        _probeProvider(wasm: wasm, tmdb: tmdb, job: job, gen: gen)
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
          if (settled >= jobs.length) {
            finish(null);
          }
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
    if (gen == _generation) {
      _generation++;
    }
    _sharedClient?.close();
    _sharedClient = null;
  }

  Future<ExtractedMedia?> _probeProvider({
    required _VideasyWasm wasm,
    required int tmdb,
    required _ProviderJob job,
    required int gen,
  }) async {
    if (gen != _generation) return null;

    final uri = Uri.https(
      job.host,
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

    if (res.statusCode != 200 || res.body.length < 100) {
      onLog('[Videasy] ${job.provider} -> ${res.statusCode} '
          '(${res.body.length} bytes), skip');
      return null;
    }

    final hex = res.body.trim();
    String intermediate;
    try {
      intermediate = await wasm.decrypt(hex, tmdb);
    } catch (e) {
      onLog('[Videasy] ${job.provider} WASM decrypt error: $e');
      return null;
    }
    if (gen != _generation) return null;

    String json;
    try {
      final raw =
          await runOpensslAesDecryptJson(intermediate, passphrase: '');
      if (raw.startsWith('{')) {
        final probe = jsonDecode(raw) as Map<String, dynamic>;
        if (probe.containsKey('error') && !probe.containsKey('sources')) {
          onLog('[Videasy] ${job.provider} AES decrypt error: ${probe['error']}');
          return null;
        }
      }
      json = raw;
    } catch (e) {
      onLog('[Videasy] ${job.provider} AES decrypt error: $e');
      return null;
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(json) as Map<String, dynamic>;
    } catch (e) {
      onLog('[Videasy] ${job.provider} JSON parse error: $e');
      return null;
    }

    final parsed = _parsePayload(data, job.provider);
    if (parsed == null) return null;

    onLog('[Videasy] ${job.provider} -> ${parsed.sources?.length ?? 0} sources, '
        '${parsed.externalSubtitles?.length ?? 0} subs');
    return parsed;
  }

  ExtractedMedia? _parsePayload(Map<String, dynamic> data, String provider) {
    final srcs = (data['sources'] as List?) ?? const [];
    final subs = (data['subtitles'] as List?) ?? const [];
    if (srcs.isEmpty) return null;

    final sources = <StreamSource>[];
    for (final s in srcs) {
      if (s is! Map) continue;
      final url = (s['url'] ?? s['file'] ?? '').toString();
      if (url.isEmpty) continue;
      final quality =
          (s['quality'] ?? s['label'] ?? s['title'] ?? 'auto').toString();
      final type = (s['type'] ?? (url.contains('.m3u8') ? 'hls' : 'video'))
          .toString();
      sources.add(StreamSource(
        url: url,
        title: '$provider · $quality',
        type: type,
        headers: _playbackHeaders,
      ));
    }
    if (sources.isEmpty) return null;

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

    sources.sort((a, b) => _qualityRank(b.title) - _qualityRank(a.title));
    return ExtractedMedia(
      url: sources.first.url,
      headers: _playbackHeaders,
      sources: sources,
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

  static String doubleEncodeTitle(String title) =>
      Uri.encodeComponent(Uri.encodeComponent(title));

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

class _ProviderJob {
  const _ProviderJob({
    required this.host,
    required this.provider,
    required this.query,
  });

  final String host;
  final String provider;
  final Map<String, String> query;
}

class _VideasyWasm {
  _VideasyWasm._();
  static final _VideasyWasm instance = _VideasyWasm._();

  HeadlessInAppWebView? _hw;
  InAppWebViewController? _controller;
  Completer<bool>? _ready;

  Future<_VideasyWasm?> ensureReady(
      {required void Function(String) onLog}) async {
    if (_ready != null) {
      final ok = await _ready!.future;
      return ok ? this : null;
    }
    if (SettingsService.platformProfile == PlatformProfile.androidTv) {
      onLog('[Videasy] WASM WebView blocked on Android TV');
      _ready = Completer<bool>()..complete(false);
      return null;
    }
    _ready = Completer<bool>();

    try {
      final bytes = await rootBundle.load('assets/videasy/module.wasm');
      final wasmB64 = base64Encode(bytes.buffer.asUint8List());

      const html = '''
<!doctype html><html><head><meta charset="utf-8"></head><body>
<script>
(function(){
  function b64ToBytes(b64){
    var bin = atob(b64), len = bin.length, out = new Uint8Array(len);
    for (var i = 0; i < len; i++) out[i] = bin.charCodeAt(i);
    return out;
  }
  window.__init = async function(b64){
    try {
      var bytes = b64ToBytes(b64);
      var imports = {
        env: {
          abort: function(m,f,l,c){ throw new Error('wasm abort '+m+':'+l+':'+c); },
          seed: function(){ return Date.now(); }
        }
      };
      var inst = await WebAssembly.instantiate(bytes, imports);
      var E = inst.instance.exports;
      var mem = E.memory;
      function readStr(ptr){
        if (!ptr) return null;
        var dv = new DataView(mem.buffer);
        var bl = dv.getUint32(ptr - 4, true);
        return new TextDecoder('utf-16le').decode(new Uint8Array(mem.buffer, ptr, bl));
      }
      function writeStr(s){
        var u = new Uint16Array(s.length);
        for (var i = 0; i < s.length; i++) u[i] = s.charCodeAt(i);
        var ptr = E.__new(u.length * 2, 1);
        new Uint8Array(mem.buffer, ptr, u.length * 2).set(new Uint8Array(u.buffer));
        E.__pin(ptr);
        return ptr;
      }
      window.videasy_decrypt = function(hex, tmdbId){
        var p = writeStr(hex);
        var rp = E.decrypt(p, tmdbId) >>> 0;
        return readStr(rp);
      };
      return 'ok';
    } catch (e) {
      return 'err:' + (e && e.message || String(e));
    }
  };
})();
</script></body></html>
''';

      final completer = Completer<void>();
      _hw = HeadlessInAppWebView(
        initialData: InAppWebViewInitialData(
          data: html,
          mimeType: 'text/html',
          encoding: 'utf-8',
          baseUrl: WebUri('about:blank'),
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
          onLog('[Videasy/wasm-console] ${msg.message}');
        },
      );
      await _hw!.run();
      await completer.future.timeout(const Duration(seconds: 15));

      final res = await _controller!.callAsyncJavaScript(
        functionBody: 'return await window.__init(b64);',
        arguments: {'b64': wasmB64},
      );
      if (res?.error != null) {
        onLog('[Videasy] WASM init JS error: ${res!.error}');
        _ready!.complete(false);
        return null;
      }
      final value = res?.value?.toString() ?? '';
      if (!value.startsWith('ok')) {
        onLog('[Videasy] WASM init failed: $value');
        _ready!.complete(false);
        return null;
      }

      onLog('[Videasy] WASM runtime ready');
      _ready!.complete(true);
      return this;
    } catch (e, st) {
      onLog('[Videasy] WASM bootstrap failed: $e\n$st');
      if (!_ready!.isCompleted) _ready!.complete(false);
      return null;
    }
  }

  Future<String> decrypt(String hex, int tmdbId) async {
    final c = _controller;
    if (c == null) throw StateError('WASM controller not initialized');
    final res = await c.callAsyncJavaScript(
      functionBody: 'return window.videasy_decrypt(hex, tmdbId);',
      arguments: {'hex': hex, 'tmdbId': tmdbId},
    );
    if (res?.error != null) throw Exception('JS: ${res!.error}');
    final v = res?.value;
    if (v is! String || v.isEmpty) {
      throw Exception('empty decrypt result (${v.runtimeType})');
    }
    return v;
  }
}
